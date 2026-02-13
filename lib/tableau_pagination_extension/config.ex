defmodule TableauPaginationExtension.Config do
  @moduledoc false

  alias TableauPaginationExtension.ListPager
  alias TableauPaginationExtension.TagIndexPager
  alias TableauPaginationExtension.TagPagePager

  def config(config) when is_list(config), do: config(Map.new(config))

  def config(config) do
    case Map.fetch(config, :collections) do
      :error ->
        {:error, ":collections is required"}

      {:ok, collections} ->
        case validate_collections(collections) do
          {:error, reason} ->
            {:error, reason}

          validated_collections ->
            config =
              config
              |> Map.put_new(:enabled, false)
              |> Map.put(:collections, validated_collections)

            {:ok, config}
        end
    end
  end

  defp validate_collections(collections), do: Enum.reduce_while(collections, %{}, &validate_collection/2)

  defp validate_collection({key, opts}, collections) when is_list(opts),
    do: validate_collection({key, Map.new(opts)}, collections)

  defp validate_collection({key, opts}, collections) do
    {handler, default_sort} =
      case resolve_type(key) || resolve_type(opts[:type]) do
        nil -> {opts[:handler] || ListPager, opts[:sort] || {:date, {:desc, Date}}}
        {h, s} -> {h, s}
      end

    opts = Map.merge(%{handler: handler, sort: default_sort, key_path: [key], per_page: 10}, opts)

    case parse_permalink_option(opts) do
      {:ok, opts} ->
        {:cont, Map.put(collections, key, opts)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  @inferred_type %{
    pages: {ListPager, :title},
    posts: {ListPager, {:date, {:desc, Date}}},
    tag_index: {TagIndexPager, :title},
    tag_pages: {TagPagePager, {:date, {:desc, Date}}}
  }

  defp resolve_type(type) when is_atom(type), do: @inferred_type[type]

  defp parse_permalink_option(opts) do
    with {:ok, permalink} <- Map.fetch(opts, :permalink),
         {:ok, permalink} <- parse_permalink(permalink),
         {:ok, permalink} <- validate_permalink_placeholders(permalink, opts) do
      {:ok, Map.put(opts, :permalink, permalink)}
    else
      :error ->
        {:error, "permalink required"}

      error ->
        error
    end
  end

  defp validate_permalink_placeholders(permalink, opts) do
    with :ok <- validate_permalink_has_page(permalink),
         :ok <- validate_permalink_has_handler_placeholder(permalink, opts) do
      {:ok, permalink}
    end
  end

  defp validate_permalink_has_page(%{first: first, rest: rest}) do
    with :ok <- validate_first(first) do
      validate_rest(rest)
    end
  end

  def validate_permalink_has_handler_placeholder(permalink, %{handler: handler}) do
    case Code.ensure_loaded(handler) do
      {:module, ^handler} ->
        if function_exported?(handler, :validate_permalink, 1) do
          handler.validate_permalink(permalink)
        else
          :ok
        end

      {:error, _reason} ->
        {:error, "handler #{inspect(handler)} could not be loaded"}
    end
  end

  defp validate_first(nil), do: :ok

  defp validate_first(first) do
    case {String.contains?(first, ":page"), ends_with_page?(first)} do
      {true, true} -> :ok
      {false, _} -> :ok
      _ -> {:error, "permalink :first must contain :page placeholder at the end"}
    end
  end

  defp validate_rest(rest) do
    if ends_with_page?(rest) do
      :ok
    else
      {:error, "permalink :rest must contain :page placeholder at the end"}
    end
  end

  defp ends_with_page?(value), do: String.ends_with?(value, ":page")

  defp parse_permalink(permalink) when is_binary(permalink) do
    if String.contains?(permalink, ":page") do
      case {String.contains?(permalink, ":page?"), String.ends_with?(permalink, ":page?")} do
        {true, true} ->
          base =
            permalink
            |> String.trim_trailing(":page?")
            |> String.trim_trailing("/")

          {:ok, %{first: base, rest: "#{base}/:page"}}

        {true, false} ->
          {:error, "permalink with :page? placeholder must be at the end"}

        {false, _} ->
          {:ok, %{first: nil, rest: permalink}}
      end
    else
      {:error, "permalink must contain :page or :page? placeholder"}
    end
  end

  defp parse_permalink(permalink) do
    permalink = Map.new(permalink)

    with {:ok, first} <- Map.fetch(permalink, :first),
         {:ok, rest} <- Map.fetch(permalink, :rest) do
      {:ok, %{first: first, rest: rest}}
    else
      _ ->
        {:error, "permalink map or keyword list must have :first and :rest keys"}
    end
  end
end
