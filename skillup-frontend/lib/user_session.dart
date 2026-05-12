/// Simple singleton to store the current logged-in user's data in memory.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  int userId = 0;
  String userName = '';
  String userEmail = '';
  String token = '';

  void set({
    required int id,
    required String name,
    required String email,
    required String token,
  }) {
    userId = id;
    userName = name;
    userEmail = email;
    this.token = token;
  }

  void clear() {
    userId = 0;
    userName = '';
    userEmail = '';
    token = '';
  }

  bool get isLoggedIn => userId > 0;
}
