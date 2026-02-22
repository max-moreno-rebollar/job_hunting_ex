defmodule JobHuntingExWeb.ListingController do
  use JobHuntingExWeb, :controller

  def show(conn, _params) do
    render(conn, :home)
  end
end
