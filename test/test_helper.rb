require "orchestrate/api"
require "minitest/autorun"
require "json"
require "base64"
require "faraday"
require "securerandom"
require "time"
require "logger"

class ParallelTest < Faraday::Adapter::Test
  self.supports_parallel = true
  extend Faraday::Adapter::Parallelism

  class Manager
    def initialize
      @queue = []
    end

    def queue(env)
      @queue.push(env)
    end

    def run
      @queue.each {|env| env[:response].finish(env) }
    end
  end

  def self.setup_parallel_manager(options={})
    @mgr ||= Manager.new
  end

  def call(env)
    super(env)
    env[:parallel_manager].queue(env)
    env[:response]
  end
end

Faraday::Adapter.register_middleware :parallel_test => :ParallelTest

# Test Helpers ---------------------------------------------------------------

def output_message(name, msg = nil)
  msg ||= "START TEST"
end

# TODO this is a bit messy for now at least but there's a bunch of
# intermediate state we'd have to deal with in a bunch of other places
def make_client_and_artifacts(parallel=false)
  api_key = SecureRandom.hex(24)
  basic_auth = "Basic #{Base64.encode64("#{api_key}:").gsub(/\n/,'')}"
  stubs = Faraday::Adapter::Test::Stubs.new
  client = Orchestrate::Client.new(api_key) do |f|
    if parallel
      f.adapter :parallel_test, stubs
    else
      f.adapter :test, stubs
    end
    f.response :logger, Logger.new(File.join(File.dirname(__FILE__), "test.log"))
  end
  [client, stubs, basic_auth]
end

def capture_warnings
  old, $stderr = $stderr, StringIO.new
  begin
    yield
    $stderr.string
  ensure
    $stderr = old
  end
end

def response_headers(specified={})
  {
    'Content-Type' => 'application/json',
    'X-Orchestrate-Req-Id' => SecureRandom.uuid,
    'Date' => Time.now.httpdate,
    'Connection' => 'keep-alive'
  }.merge(specified)
end

def chunked_encoding_header
  { 'transfer-encoding' => 'chunked' }
end

def response_not_found(items)
{ "message" => "The requested items could not be found.",
  "details" => {
    "items" => [ items ]
  },
  "code" => "items_not_found"
}.to_json
end

# Assertion Helpers

def assert_header(header, expected, env)
  assert_equal expected, env.request_headers[header]
end

def assert_authorization(expected, env)
  assert_header 'Authorization', expected, env
end

def assert_accepts_json(env)
  assert_match %r{application/json}, env.request_headers['Accept']
end


