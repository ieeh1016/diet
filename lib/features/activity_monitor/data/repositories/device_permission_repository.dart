import '../../../../core/permissions/permission_snapshot.dart';
import '../../../../platform/permissions/permission_service.dart';
import '../../domain/repositories/permission_repository.dart';

class DevicePermissionRepository implements PermissionRepository {
  DevicePermissionRepository(this._permissionService);

  final PermissionService _permissionService;

  @override
  Future<PermissionSnapshot> readPermissionSnapshot() =>
      _permissionService.readPermissionSnapshot();

  @override
  Future<PermissionSnapshot> requestRequiredPermissions() =>
      _permissionService.requestRequiredPermissions();
}
