abstract class CoreConfigPort {
  void invalidatePendingOperations();
  Future<void> apply(Map<String, dynamic> overlay);
  Future<void> closeApplicationConnections(Set<String> applicationIds);
}
