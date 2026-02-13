defmodule TableauPaginationExtension.TestCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import TableauPaginationExtension.TestCase
    end
  end

  def build_config(opts \\ []) do
    config_map = Map.merge(%{enabled: true}, Map.new(opts))

    case TableauPaginationExtension.config(config_map) do
      {:ok, config} -> config
      {:error, reason} -> raise "Failed to build config: #{reason}"
    end
  end

  def build_post(opts \\ []) do
    %{
      title: Keyword.get(opts, :title, "Test Post"),
      permalink: Keyword.get(opts, :permalink, "/test"),
      date: Keyword.get(opts, :date, ~U[2024-01-01 00:00:00Z]),
      body: Keyword.get(opts, :body, "Test content")
    }
  end

  def paginate_collection(collection, config_opts) do
    config = build_config(config_opts)

    token = %{
      posts: collection,
      graph: Graph.new(),
      extensions: %{paginated_indexes: %{config: config}}
    }

    {:ok, result} = TableauPaginationExtension.pre_render(token)

    # Extract pages from graph
    result.graph
    |> Graph.vertices()
    |> Enum.filter(&is_struct(&1, Tableau.Page))
    |> Enum.sort_by(& &1.opts.page_number)
  end
end
