part of 'home_screen_bloc.dart';

@immutable
sealed class HomeScreenEvent {}

final class HomeScreenLoad extends HomeScreenEvent {}

final class HomeScreenSyncRequested extends HomeScreenEvent {}

final class HomeScreenOutputDirRequested extends HomeScreenEvent {}

final class HomeScreenPauseRequested extends HomeScreenEvent {}

final class HomeScreenPlayRequested extends HomeScreenEvent {}

final class HomeScreenLogoutRequested extends HomeScreenEvent {}

final class HomeScreenSyncStatusChanged extends HomeScreenEvent {
  final ClientSyncStatus status;

  HomeScreenSyncStatusChanged(this.status);
}

final class HomeScreenSyncFailed extends HomeScreenEvent {
  final Object error;

  HomeScreenSyncFailed(this.error);
}
