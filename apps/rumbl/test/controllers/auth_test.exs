defmodule Rumbl.AuthTest do
  use Rumbl.ConnCase
  alias Rumbl.Auth
  alias Rumbl.User

  setup %{conn: conn} do
    conn =
      conn
      |> bypass_through(Rumbl.Router, :browser)
      |> get("/")

    {:ok, conn: conn}
  end

  test "authenticate_user halts when current_user doesn't exist", %{conn: conn} do
    conn = Auth.authenticate_user(conn, [])
    assert conn.halted
  end

  test "authenticate_user continue when current_user exists", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, %User{})
      |> Auth.authenticate_user([])

    refute conn.halted
  end

  test "login puts the user in the session", %{conn: conn} do
    login_conn =
      conn
      |> Auth.login(%User{id: 123})
      |> send_resp(:ok, "")

    next_conn = get login_conn, "/"
    assert get_session(next_conn, :user_id) === 123
  end

  test "logout drops session", %{conn: conn} do
    login_conn =
      conn
      |> put_session(:user_id, 123)
      |> Auth.logout
      |> send_resp(:ok, "")

    next_conn = get login_conn, "/"
    refute get_session(next_conn, :user_id)
  end

  test "call places user from session into assigns", %{conn: conn} do
    user = insert_user()

    conn =
      conn
      |> put_session(:user_id, user.id)
      |> Auth.call(Repo)

    assert conn.assigns.current_user.id == user.id
  end

  test "call with no session sets current_user to nill", %{conn: conn} do
    conn = Auth.call(conn, Repo)
    refute conn.assigns.current_user
  end

  test "login with valid username and password", %{conn: conn} do
    user = insert_user(username: "me", password: "password")
    {:ok, conn} = Auth.login_by_username_and_password(conn, "me", "password", repo: Repo)
    assert conn.assigns.current_user.id == user.id
  end

  test "login with a not found user", %{conn: conn} do
    assert {:error, :not_found, _conn} =
      Auth.login_by_username_and_password(conn, "me", "password", repo: Repo)
  end

  test "login with password mismatch", %{conn: conn} do
    _ = insert_user(username: "me", password: "password")
    assert {:error, :unauthorized, _conn} =
      Auth.login_by_username_and_password(conn, "me", "wrong", repo: Repo)
  end
end
