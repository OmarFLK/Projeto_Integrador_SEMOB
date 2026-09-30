import '../models/user.dart';

const currentUser = AppUser(
  name: 'Marina Oliveira',
  identifier: 'marina.oliveira@semob.scs.gov.br',
  role: 'Coordenadora de Operações',
  department: 'Operação e Planejamento',
  accessLevel: AccessLevel.administrator,
  status: 'Ativo',
  lastAccess: 'Hoje, 08:42',
);

const mockUsers = <AppUser>[
  currentUser,
  AppUser(
    name: 'Rafael Santos',
    identifier: '45721',
    role: 'Analista de Mobilidade',
    department: 'Planejamento',
    accessLevel: AccessLevel.analyst,
    status: 'Ativo',
    lastAccess: 'Hoje, 08:15',
  ),
  AppUser(
    name: 'Camila Souza',
    identifier: '46208',
    role: 'Operadora',
    department: 'Centro de Controle',
    accessLevel: AccessLevel.operator,
    status: 'Ativo',
    lastAccess: 'Ontem, 17:48',
  ),
  AppUser(
    name: 'Paulo Mendes',
    identifier: 'paulo.mendes@semob.scs.gov.br',
    role: 'Gerente',
    department: 'Gestão',
    accessLevel: AccessLevel.manager,
    status: 'Ativo',
    lastAccess: '29/09/2026, 15:20',
  ),
  AppUser(
    name: 'Larissa Lima',
    identifier: '45119',
    role: 'Analista de Dados',
    department: 'Inteligência',
    accessLevel: AccessLevel.analyst,
    status: 'Inativo',
    lastAccess: '12/09/2026, 11:03',
  ),
];
