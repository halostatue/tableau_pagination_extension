defmodule TableauPaginationExtension.MapPagePager do
  @moduledoc """
  Pager for paginating each value list in a map separately.

  This handler iterates over a map and generates paginated pages for each value list. The
  map key is incorporated into the permalink.

  ## Example

  ```elixir
  collections: [
    category_pages: [
      handler: MapPagePager,
      key_path: [:categories],
      permalink: "/categories/:key/:page?",
      per_page: 20
    ]
  ]
  ```

  The `:key` placeholder in the permalink will be replaced with the map key as a string.
  """

  @behaviour TableauPaginationExtension.Pager

  alias TableauPaginationExtension.Pager

  @impl Pager
  def validate_permalink(%{first: first, rest: rest}) do
    if (is_nil(first) or String.contains?(first, ":key")) and String.contains?(rest, ":key") do
      :ok
    else
      {:error, "MapPagePager requires :key placeholder in permalink"}
    end
  end

  @impl Pager
  def paginate(token, opts) do
    case get_in(token, opts.key_path) do
      map when is_map(map) -> Enum.flat_map(map, &build_key_pages(&1, opts))
      # coveralls-ignore-next-line
      _ -> []
    end
  end

  defp build_key_pages({key, items}, opts) do
    items
    |> Pager.sort_collection(opts.sort)
    |> Pager.build_pages(opts.per_page, build_key_permalink(opts.permalink, key), opts.layout, opts.template)
  end

  defp build_key_permalink(permalink, key) do
    key = to_string(key)

    %{
      first: replace_key_placeholder(permalink.first, key),
      rest: replace_key_placeholder(permalink.rest, key)
    }
  end

  defp replace_key_placeholder(nil, _key), do: nil
  defp replace_key_placeholder(pattern, key), do: String.replace(pattern, ":key", key)
end
