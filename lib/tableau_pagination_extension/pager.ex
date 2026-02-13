defmodule TableauPaginationExtension.Pager do
  @moduledoc """
  Behaviour for collection pagers and shared pagination utilities.

  Pagers are responsible for extracting items from the token and generating paginated
  pages for them.
  """

  @type tableau_page :: %Tableau.Page{}

  @doc """
  Generate paginated pages for a collection. Returns a list of `Tableau.Page` structs.
  """
  @callback paginate(Tableau.Extension.token(), opts :: map()) :: [tableau_page()]

  @doc """
  Validate permalink requirements for this pager.

  Optional callback. If not implemented, no validation is performed.
  Receives the parsed permalink map with `:first` and `:rest` keys.
  """
  @callback validate_permalink(permalink :: %{first: nil | String.t(), rest: String.t()}) :: :ok | {:error, String.t()}

  @optional_callbacks validate_permalink: 1

  @type direction :: :asc | :desc | {:asc | :desc, module()}

  @type sort_rule ::
          false
          | atom()
          | {field :: atom(), direction()}
          | {extractor :: (term() -> term) | mfa(), direction()}
          | (term(), term() -> boolean())
          | mfa()

  @doc """
  Sort a collection according to the sort configuration.
  """
  @spec sort_collection(list(), sort_rule()) :: list()

  def sort_collection(items, false), do: items

  def sort_collection(items, field) when is_atom(field) do
    direction = if field == :date, do: {:desc, Date}, else: :asc
    Enum.sort_by(items, &Map.get(&1, field), direction)
  end

  def sort_collection(items, {field, direction}) when is_atom(field) do
    Enum.sort_by(items, &Map.get(&1, field), normalize_direction(field, direction))
  end

  def sort_collection(items, {extractor, direction}) when is_function(extractor, 1) do
    Enum.sort_by(items, extractor, direction)
  end

  def sort_collection(items, {{module, function, args}, direction}) do
    extractor = fn item -> apply(module, function, [item | args]) end
    Enum.sort_by(items, extractor, direction)
  end

  def sort_collection(items, comparator) when is_function(comparator, 2) do
    Enum.sort(items, comparator)
  end

  def sort_collection(items, {module, function, args}) do
    comparator = fn item1, item2 -> apply(module, function, [item1, item2 | args]) end
    Enum.sort(items, comparator)
  end

  @type permalink :: %{first: nil | String.t(), rest: String.t()}

  @doc """
  Generate paginated pages for a list of items.
  """
  @spec build_pages(list, pos_integer(), permalink(), module(), module()) :: [tableau_page()]
  def build_pages([], _size, _permalink, _layout, _template), do: []

  def build_pages(items, per_page, permalink, layout, template) do
    chunks = Enum.chunk_every(items, per_page)
    total_pages = length(chunks)

    chunks
    |> Enum.with_index(1)
    |> Enum.map(&build_page(&1, total_pages, permalink, layout, template))
  end

  defp build_page({page_items, page_num}, total_pages, permalink, layout, template) do
    page_permalink = build_page_url(page_num, permalink)

    %Tableau.Page{
      parent: layout,
      permalink: page_permalink,
      template: &template.template/1,
      opts: %{
        posts: page_items,
        page_number: page_num,
        total_pages: total_pages,
        prev_page: if(page_num > 1, do: page_num - 1),
        next_page: if(page_num < total_pages, do: page_num + 1),
        first_page_url: build_page_url(1, permalink),
        prev_page_url: if(page_num > 1, do: build_page_url(page_num - 1, permalink)),
        next_page_url: if(page_num < total_pages, do: build_page_url(page_num + 1, permalink)),
        last_page_url: build_page_url(total_pages, permalink)
      }
    }
  end

  defp build_page_url(page_num, permalink) do
    if page_num == 1 && permalink.first do
      permalink.first
    else
      String.replace(permalink.rest, ":page", to_string(page_num))
    end
  end

  defp normalize_direction(:date, :asc), do: {:asc, Date}
  defp normalize_direction(:date, :desc), do: {:desc, Date}
  defp normalize_direction(:date, direction), do: direction
  defp normalize_direction(_field, direction), do: direction
end
