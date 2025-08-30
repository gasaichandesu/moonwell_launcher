part of 'home_screen_bloc.dart';

@immutable
sealed class HomeScreenEvent {}

final class HomeScreenLoad extends HomeScreenEvent {}

final class HomeScreenDownloadRequested extends HomeScreenEvent {}

final class HomeScreenOutputDirRequested extends HomeScreenEvent {}

final class HomeScreenDownloadPaused extends HomeScreenEvent {}

final class HomeScreenDownloadProgressUpdated extends HomeScreenEvent {
  final DownloadProgress progress;

  HomeScreenDownloadProgressUpdated(this.progress);
}
