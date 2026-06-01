defmodule Brain2Web.PageController do
  use Brain2Web, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
