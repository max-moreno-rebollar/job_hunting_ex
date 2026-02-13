defmodule JobHuntingEx.Router do
  use Plug.Router

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  get "/home" do
    html = render_template("home.html.eex", title: "Query")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  post "/home" do
    IO.inspect(conn.body_params)

    conn
    |> send_resp(200, "nice")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  def render_template(template_name, assigns) do
    appdir = :code.priv_dir(:job_hunting_ex)
    template_path = Path.join(appdir, "templates/#{template_name}")
    EEx.eval_file(template_path, assigns: assigns)
  end
end
