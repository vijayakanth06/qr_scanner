/// Domain-specific scan errors representing all failure modes for barcode scans.
sealed class ScanError {
  const ScanError();
}

class MalformedInput extends ScanError {
  const MalformedInput({required this.rawValue});

  final String rawValue;
}

class UnknownRoll extends ScanError {
  const UnknownRoll({required this.rollNo});

  final String rollNo;
}

class CooldownActive extends ScanError {
  const CooldownActive({required this.rollNo, required this.remainingSeconds});

  final String rollNo;
  final int remainingSeconds;
}

class DuplicateExit extends ScanError {
  const DuplicateExit({required this.rollNo});

  final String rollNo;
}

class OfflineLookupMiss extends ScanError {
  const OfflineLookupMiss({required this.rollNo});

  final String rollNo;
}

class ScannerHardwareError extends ScanError {
  const ScannerHardwareError({required this.message});

  final String message;
}
