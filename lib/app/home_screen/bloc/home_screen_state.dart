part of 'home_screen_bloc.dart';

@immutable
sealed class HomeScreenState {
  final HomeScreenModel model;

  const HomeScreenState({required this.model});
}

final class HomeScreenInitialState extends HomeScreenState {
  const HomeScreenInitialState({required super.model});
}

final class HomeScreenReadyToDownloadState extends HomeScreenState {
  const HomeScreenReadyToDownloadState({required super.model});
}

final class HomeScreenDownloadPausedState extends HomeScreenState {
  const HomeScreenDownloadPausedState({required super.model});
}

final class HomeScreenDownloadingState extends HomeScreenState {
  const HomeScreenDownloadingState({required super.model});
}
