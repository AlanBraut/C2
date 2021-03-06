require "elasticsearch/extensions/test/cluster"

module EsSpecHelper
  def es_mock_bad_gateway
    allow_any_instance_of(Elasticsearch::Transport::Client)
      .to receive(:perform_request)
      .and_raise(Elasticsearch::Transport::Transport::Errors::BadGateway, "oops, can't find ES service")
  end

  def es_mock_connection_failed
    allow_any_instance_of(Elasticsearch::Transport::Client)
      .to receive(:perform_request)
      .and_raise(Faraday::ConnectionFailed, "oops, connection failed")
  end

  def start_es_server
    # circleci has locally installed version of elasticsearch so alter PATH to find
    ENV["PATH"] = "./elasticsearch/bin:#{ENV['PATH']}"

    es_test_cluster_opts = {
      nodes: 1,
      path_logs: "tmp/es-logs"
    }

    Elasticsearch::Extensions::Test::Cluster.start(es_test_cluster_opts)
  end

  def stop_es_server
    if es_server_running?
      Elasticsearch::Extensions::Test::Cluster.stop
    end
  end

  def es_server_running?
    `ps x | grep 'es.path.data=/tmp/elasticsearch_test' | grep -v grep`
    debug { "Running? #{$CHILD_STATUS.success?}" }
    $CHILD_STATUS.success?
  end

  def create_es_index(klass)
    debug { "Rebuilding index for #{klass}..." }
    search = klass.__elasticsearch__
    _create search, name: klass.index_name
    _import search
    _refresh search
  end

  def _create(search, name: nil)
    debug { "  Creating index..." }
    search.create_index!(
      # Req'd by https://github.com/elastic/elasticsearch-rails/issues/571
      force: search.index_exists?(index: name),
      index: name
    )
  end

  def _import(search)
    debug { "  Importing data..." }
    search.import(return: "errors", batch_size: 200) do |resp|
      errors    = resp["items"].select { |k, _v| k.values.first["error"] }
      completed = resp["items"].size
      debug { "Finished #{completed} items" }
      debug { "ERRORS in #{$PROCESS_ID}: #{errors.pretty_inspect}" } unless errors.empty?
      [STDOUT, STDERR].each(&:flush)
    end
  end

  def _refresh(search)
    debug { "  Refreshing index..." }
    search.refresh_index!
  end

  # h/t https://devmynd.com/blog/2014-2-dealing-with-failing-elasticserach-tests/
  # rubocop:disable Metrics/MethodLength
  def es_execute_with_retries(retries = 3)
    begin
      retries -= 1
      yield
    rescue SearchUnavailable => error
      if retries > 0
        sleep 0.5
        retry
      else
        puts "retries: #{retries}"
        raise error
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  def debug
    if ENV["ES_DEBUG"]
      puts yield
    end
  end
end

RSpec.configure do |config|
  include EsSpecHelper

  config.before :suite do
    debug { "before :suite" }
    start_es_server unless es_server_running?
    create_es_index(Proposal)
  end
end
