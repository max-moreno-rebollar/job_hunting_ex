defmodule JobHuntingExWeb.ListingController do
  use JobHuntingExWeb, :controller

  def show(conn, params) do
    render(conn, :home)
  end
end
