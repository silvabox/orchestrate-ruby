module Orchestrate::Error
  # given a response and a possible JSON response body, raises the
  # appropriate Exception
  def self.handle_response(response)
    err_type = ERRORS.find do |err|
      err.status == response.status && err.code == response.body['code']
    end
    if err_type
      raise err_type.new(response)
    elsif response.status >= 400
      raise RequestError.new(response)
    end
  end

  # Base class for Errors when talking to the Orchestrate API.
  class Base < StandardError
    # class-level attr-reader for the error's response code.
    def self.status; @status; end

    # class-level attr-reader for the error's code.
    def self.code; @code; end

    # The response that triggered the error.
    attr_reader :response

    def initialize(response)
      @resposne = response
      super(response.body['message'])
    end
  end

  # indicates a 4xx-class response, and the problem was with the request.
  class RequestError < Base; end

  # The client provided a malformed request.
  class BadRequest < RequestError
    @status = 400
    @code   = 'api_bad_request'
  end

  # The client provided a malformed search query.
  class MalformedSearch < RequestError
    @status = 400
    @code   = 'search_query_malformed'
  end

  # The client provided a ref value that is not valid.
  class MalformedRef < RequestError
    @status = 400
    @code   = 'item_ref_malformed'
  end

  # When a Search Parameter is recognized, but not valid.  For example, a limit
  # exceeding 100.
  class InvalidSearchParam < RequestError
    @status = 400
    @code   = 'search_param_invalid'
  end

  # A Valid API key was not provided.
  class Unauthorized < RequestError
    @status = 401
    @code   = 'security_unauthorized'
  end

  # Something the user expected to be there was not.
  class NotFound < RequestError
    @status = 404
    @code   = 'items_not_found'
  end

  # When a new collection is created by its first KV document, a schema is created
  # for indexing, including the types of the values for the KV document.  This error
  # will occur when a new document provides values with different types.  Values with
  # unexpected types will not be indexed.  Since search is an implicit feature
  # of the service, this is an error and worth raising an exception over.
  #
  # Example:
  #   client.put(:test, :first, { "count" => 0 }) # establishes 'count' as a Long
  #   client.put(:test, :second, { "count" => "none" }) # 'count' is not a Long
  #
  class IndexingConflict < RequestError
    @status = 409
    @code   = 'indexing_conflict'
  end

  # Client provided a ref that is not the current ref.
  class VersionMismatch < RequestError
    @status = 412
    @code   = 'item_version_mismatch'
  end

  # Client provided "If-None-Match", but something matched.
  class AlreadyPresent < RequestError
    @status = 412
    @code   = 'item_already_present'
  end

  ERRORS=[ BadRequest, MalformedSearch, MalformedRef, InvalidSearchParam,
           Unauthorized, NotFound, IndexingConflict,
           VersionMismatch, AlreadyPresent
          ]

  def self.errors
    @@errors ||= [
      { :status => 500,
        :code   => :security_authentication,
        :desc   => 'An error occurred while trying to authenticate.'
      },
      { :status => 500,
        :code   => :search_index_not_found,
        :desc   => 'Index could not be queried for this application.'
      },
      { :status => 500,
        :code   => :internal_error,
        :desc   => 'Internal Error.'
      }
  ]
  end
end
