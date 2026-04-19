class AppException implements Exception {
  const AppException({
    required this.code,
    required this.userMessage,
    this.details,
  });

  final int code;
  final String userMessage;
  final String? details;

  @override
  String toString() => 'AppException($code): $userMessage';
}

class AppErrorInfo {
  const AppErrorInfo({required this.code, required this.message, this.details});

  final int code;
  final String message;
  final String? details;
}

AppErrorInfo describeAppError(
  Object error, {
  required int fallbackCode,
  required String fallbackMessage,
}) {
  if (error is AppException) {
    return AppErrorInfo(
      code: error.code,
      message: error.userMessage,
      details: error.details,
    );
  }

  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  return AppErrorInfo(
    code: fallbackCode,
    message: fallbackMessage,
    details: raw.isEmpty ? null : raw,
  );
}
