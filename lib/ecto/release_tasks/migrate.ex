defmodule Ecto.ReleaseTasks.Migrate do
  # Based on mix ecto.migrate
  # https://github.com/elixir-ecto/ecto_sql/blob/5e78291dbc8c0c6d249d8ad7150c120a4a836c59/lib/mix/tasks/ecto.migrate.ex

  @shortdoc "Runs the repository migrations"

  @aliases [
    n: :step,
    r: :repo
  ]

  @switches [
    all: :boolean,
    step: :integer,
    to: :integer,
    quiet: :boolean,
    prefix: :string,
    pool_size: :integer,
    log_sql: :boolean,
    strict_version_order: :boolean,
    repo: [:keep, :string]
  ]

  @moduledoc """
  Runs the pending migrations for the given repository.

  This task runs all pending migrations by default. To migrate up to a
  specific version number, supply `--to version_number`. To migrate a
  specific number of times, use `--step n`.

  EXAMPLES

    ecto migrate
    ecto migrate -r Custom.Repo
    ecto migrate -n 3
    ecto migrate --step 3
    ecto migrate -v 20080906120000
    ecto migrate --to 20080906120000

  OPTIONS

    -r, --repo              the repo to migrate
    --all                   run all pending migrations
    --step, -n              run n number of pending migrations
    --to                    run all migrations up to and including version
    --quiet                 do not log migration commands
    --prefix                the prefix to run migrations on
    --pool-size             the pool size if the repository is started only for
                            the task (defaults to 1)
    --log-sq                log the raw sql migrations are running
    --strict-version-order  abort when applying a migration with old timestamp
  """

  use Ecto.ReleaseTasks.Task

  def run(args, migrator \\ &Ecto.Migrator.run/4) do
    repos = parse_repo(args)
    {opts, _} = OptionParser.parse! args, strict: @switches, aliases: @aliases

    opts =
      if opts[:to] || opts[:step] || opts[:all],
        do: opts,
        else: Keyword.put(opts, :all, true)

    opts =
      if opts[:quiet],
        do: Keyword.merge(opts, [log: false, log_sql: false]),
        else: opts

    Enum.each repos, fn repo ->
      ensure_repo(repo)
      path = ensure_migrations_path(repo)
      {:ok, pid, apps} = ensure_started(repo, opts)

      pool = repo.config[:pool]
      migrated =
        if function_exported?(pool, :unboxed_run, 2) do
          pool.unboxed_run(repo, fn -> migrator.(repo, path, :up, opts) end)
        else
          migrator.(repo, path, :up, opts)
        end

      pid && repo.stop()
      restart_apps_if_migrated(apps, migrated)
    end
  end
end
