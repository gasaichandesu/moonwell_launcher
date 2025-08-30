/// A use case represents a single unit of work in the application.
abstract interface class UseCase<Input, Output> {
  Output call(Input input);
}

/// A use case that returns a Future of [Output].
abstract interface class FutureUseCase<Input, Output>
    implements UseCase<Input, Future<Output>> {
  @override
  Future<Output> call(Input input);
}

/// A use case that returns a Stream of [Output].
abstract interface class StreamUseCase<Input, Output>
    implements UseCase<Input, Stream<Output>> {
  @override
  Stream<Output> call(Input input);
}
