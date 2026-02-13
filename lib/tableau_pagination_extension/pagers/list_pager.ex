defmodule TableauPaginationExtension.ListPager do
  @moduledoc """
  Pager for paginating simple list collections.

  This is the default pager and supports the current behavior of paginating collections
  like `:posts` and `:pages`.
  """

  @behaviour TableauPaginationExtension.Pager

  alias TableauPaginationExtension.Pager

  @impl Pager
  def paginate(token, opts) do
    case get_in(token, opts.key_path) do
      items when is_list(items) ->
        items
        |> Pager.sort_collection(opts.sort)
        |> Pager.build_pages(opts.per_page, opts.permalink, opts.layout, opts.template)

      # coveralls-ignore-next-line
      _ ->
        []
    end
  end
end
