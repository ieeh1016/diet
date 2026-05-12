import '../../../../core/permissions/permission_snapshot.dart';

abstract interface class PermissionRepository {
  Future<PermissionSnapshot> requestRequiredPermissions();

  Future<PermissionSnapshot> readPermissionSnapshot();
}
