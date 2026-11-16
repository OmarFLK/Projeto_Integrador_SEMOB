import 'auth_store.dart';
import 'document_store.dart';
import 'errors.dart';

/// Password proposals are never credentials until an administrator verifies the
/// claimant out of band and approves the request. Only hashes reach storage.
class ManualRecoveryStore {
  ManualRecoveryStore(this.auth, {this.lifetime = const Duration(hours: 24)});
  final AuthStore auth;
  final Duration lifetime;

  Future<String> request({
    required String name,
    required String identifier,
    required String password,
  }) async {
    name = name.trim();
    identifier = identifier.trim().toLowerCase();
    if (name.isEmpty ||
        name.length > 250 ||
        identifier.isEmpty ||
        identifier.length > 250) {
      throw const ApiError(
        400,
        'Informe nome e e-mail ou matrícula válidos (até 250 caracteres).',
      );
    }
    // Perform the same KDF even for an unknown account, before the lookup.
    final hash = await auth.hashPassword(password);
    final id = secureToken();
    await auth.db.transaction(() async {
      await expire();
      final users = await auth.db.select(
        'SELECT id FROM users WHERE (lower(email)=? OR lower(identifier)=?) AND active=1',
        [identifier, identifier],
      );
      await auth.db.execute(
        '''INSERT INTO manual_recovery_requests
        (id,user_id,declared_name,identifier,proposed_hash,expires_at)
        VALUES(?,?,?,?,?,?)''',
        [
          id,
          users.firstOrNull?['id'],
          name,
          identifier,
          users.isEmpty ? null : hash,
          DateTime.now().toUtc().add(lifetime).toIso8601String(),
        ],
      );
      await auth.log(null, 'auth.manual_recovery_requested', {'requestId': id});
    });
    return id;
  }

  /// Scrub proposals promptly; metadata is retained for at most 30 days.
  Future<void> expire() async {
    await auth.db.execute("""UPDATE manual_recovery_requests
      SET status='expired', proposed_hash=NULL, processed_at=CURRENT_TIMESTAMP
      WHERE status='pending' AND expires_at<=CURRENT_TIMESTAMP""");
    await auth.db.execute(
      "DELETE FROM manual_recovery_requests WHERE status<>'pending' AND processed_at<CURRENT_TIMESTAMP-INTERVAL '30 days'",
    );
  }

  Future<List<Document>> list({String? status}) =>
      auth.db.transaction(() async {
        await expire();
        if (status != null &&
            !const [
              'pending',
              'approved',
              'rejected',
              'expired',
              'cancelled',
            ].contains(status)) {
          throw const ApiError(400, 'Status inválido.');
        }
        return auth.db.select(
          '''SELECT r.id,r.declared_name,r.identifier,r.status,
      r.created_at,r.expires_at,r.processed_at,r.processed_by,r.notification_status,
      u.name AS account_name,u.email AS account_email,u.active AS account_active
      FROM manual_recovery_requests r LEFT JOIN users u ON u.id=r.user_id
      ${status == null ? '' : 'WHERE r.status=?'}
      ORDER BY r.created_at DESC LIMIT 200''',
          status == null ? [] : [status],
        );
      });

  Future<void> notification(String id, String state) async {
    if (!const ['not-configured', 'sent', 'failed'].contains(state)) {
      throw ArgumentError('Estado de notificação inválido.');
    }
    await auth.db.execute(
      'UPDATE manual_recovery_requests SET notification_status=? WHERE id=?',
      [state, id],
    );
  }

  Future<Document> inspect(String id) => auth.db.transaction(() async {
    await expire();
    final rows = await auth.db.select(
      '''SELECT r.id,r.status,r.expires_at,r.declared_name,r.identifier,
      u.email AS account_email,u.name AS account_name,u.active AS account_active
      FROM manual_recovery_requests r LEFT JOIN users u ON u.id=r.user_id WHERE r.id=?''',
      [id],
    );
    if (rows.length != 1) {
      throw const ApiError(404, 'Solicitação não encontrada.');
    }
    return rows.single;
  });

  Future<void> approve(
    String id, {
    required String actor,
    required bool identityVerified,
  }) async {
    if (!identityVerified) {
      throw const ApiError(
        400,
        'Confirme a identidade por um canal previamente conhecido antes de aprovar.',
      );
    }
    // Commit expiration cleanup separately so expired hashes do not survive a
    // rejected approval transaction.
    await auth.db.transaction(() => expire());
    await auth.db.transaction(() async {
      final rows = await auth.db.select(
        "SELECT * FROM manual_recovery_requests WHERE id=? AND status='pending' AND expires_at>CURRENT_TIMESTAMP FOR UPDATE",
        [id],
      );
      if (rows.length != 1) {
        throw const ApiError(
          409,
          'Solicitação indisponível, processada ou expirada.',
        );
      }
      final row = rows.single;
      final userId = row['user_id'];
      if (userId == null || row['proposed_hash'] == null) {
        throw const ApiError(
          409,
          'Não foi localizada uma conta ativa para esta solicitação.',
        );
      }
      final users = await auth.db.select(
        'SELECT id FROM users WHERE id=? AND active=1 FOR UPDATE',
        [userId],
      );
      if (users.length != 1) {
        throw const ApiError(409, 'A conta não está ativa.');
      }
      final changed = await auth.db.select(
        'UPDATE users SET password_hash=? WHERE id=? AND active=1 RETURNING id',
        [row['proposed_hash'], userId],
      );
      if (changed.length != 1) {
        throw const ApiError(409, 'A conta mudou durante a operação.');
      }
      await auth.db.execute('DELETE FROM sessions WHERE user_id=?', [userId]);
      await auth.db.execute('DELETE FROM recovery WHERE user_id=?', [userId]);
      await auth.db.execute(
        """UPDATE manual_recovery_requests
        SET status=CASE WHEN id=? THEN 'approved' ELSE 'cancelled' END,
        proposed_hash=NULL,processed_at=CURRENT_TIMESTAMP,processed_by=?
        WHERE user_id=? AND status='pending'""",
        [id, actor, userId],
      );
      await auth.log(actor, 'auth.manual_recovery_approved', {
        'requestId': id,
        'target': userId,
      });
    });
  }

  Future<void> reject(String id, {required String actor}) async {
    await auth.db.transaction(() => expire());
    await auth.db.transaction(() async {
      final rows = await auth.db.select(
        """UPDATE manual_recovery_requests SET status='rejected',
        proposed_hash=NULL,processed_at=CURRENT_TIMESTAMP,processed_by=?
        WHERE id=? AND status='pending' RETURNING id""",
        [actor, id],
      );
      if (rows.length != 1) {
        throw const ApiError(
          409,
          'Solicitação indisponível, processada ou expirada.',
        );
      }
      await auth.log(actor, 'auth.manual_recovery_rejected', {'requestId': id});
    });
  }
}

/// A single DO statement is atomic even when pasted into Neon's SQL Editor.
/// It reads the hash from the protected table instead of exporting credentials.
String manualRecoveryApprovalSql(String id) {
  if (!RegExp(r'^[A-Za-z0-9_=-]{20,128}$').hasMatch(id)) {
    throw ArgumentError('ID de solicitação inválido.');
  }
  return '''DO \$semob\$
DECLARE
  request_row manual_recovery_requests%ROWTYPE;
  changed_count INTEGER;
BEGIN
  PERFORM pg_advisory_xact_lock(73636601);
  SELECT * INTO STRICT request_row FROM manual_recovery_requests
    WHERE id='$id' AND status='pending' AND expires_at>CURRENT_TIMESTAMP FOR UPDATE;
  IF request_row.user_id IS NULL OR request_row.proposed_hash IS NULL THEN
    RAISE EXCEPTION 'Solicitação sem conta ativa vinculada';
  END IF;
  PERFORM id FROM users WHERE id=request_row.user_id AND active=1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Conta indisponível'; END IF;
  UPDATE users SET password_hash=request_row.proposed_hash WHERE id=request_row.user_id AND active=1;
  GET DIAGNOSTICS changed_count = ROW_COUNT;
  IF changed_count<>1 THEN RAISE EXCEPTION 'Quantidade de contas inesperada'; END IF;
  DELETE FROM sessions WHERE user_id=request_row.user_id;
  DELETE FROM recovery WHERE user_id=request_row.user_id;
  UPDATE manual_recovery_requests
    SET status=CASE WHEN id='$id' THEN 'approved' ELSE 'cancelled' END,
      proposed_hash=NULL,processed_at=CURRENT_TIMESTAMP,processed_by='manual:neon'
    WHERE user_id=request_row.user_id AND status='pending';
  INSERT INTO audit(user_id,action,created_at,details)
    VALUES('manual:neon','auth.manual_recovery_approved',CURRENT_TIMESTAMP,
      json_build_object('requestId','$id','target',request_row.user_id)::TEXT);
END;
\$semob\$;
''';
}
