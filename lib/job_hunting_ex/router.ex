defmodule JobHuntingEx.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  get "/hello" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, render_template("index.eex", assigns: [title: "Welcome Page"]))
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
