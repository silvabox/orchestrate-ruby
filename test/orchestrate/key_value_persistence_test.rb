require "test_helper"

class KeyValuePersistenceTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application
    @items = @app[:items]
    @kv = make_kv_item(@items, @stubs, :loaded => Time.now - 60)
  end

  def test_save_performs_put_if_match_and_returns_true_on_success
    @kv[:foo] = "bar"
    new_ref = nil
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal @kv.value, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      new_ref = make_ref
      [ 201, response_headers({'Etag' => new_ref, "Location" => "/v0/items/#{@kv.key}/refs/#{new_ref}"}), '' ]
    end
    assert_equal true, @kv.save
    assert_equal new_ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1
  end

  def test_save_performs_put_if_match_and_returns_false_on_version_mismatch
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      error_response(:version_mismatch)
    end
    assert_equal false, @kv.save
  end

  def test_save_performs_put_if_match_and_returns_true_on_indexing_conflict
    ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      ref = make_ref
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      error_response(:indexing_conflict, {
        headers: {"Location" => "/v0/items/#{@kv.key}/refs/#{ref}"},
        conflicts_uri: "/v0/items/#{@kv.key}/refs/#{ref}/conflicts"
      })
    end
    assert_equal true, @kv.save
    assert_equal ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1
  end

  def test_save_returns_false_on_etc_errors
    @stubs.put("/v0/items/#{@kv.key}") { error_response(:bad_request) }
    assert_equal false, @kv.save

    @stubs.put("/v0/items/#{@kv.key}") { error_response(:service_error) }
    assert_equal false, @kv.save
  end

  def test_save_bang_performs_put_if_match_doesnt_raise_on_success
    @kv[:foo] = "bar"
    ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal @kv.value, JSON.parse(env.body)
      assert_header 'If-Match', %|"#{ref}"|, env
      ref = make_ref
      [201, response_headers({'Etag'=>%|"#{ref}"|, 'Loation'=>"/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.save!
    assert_equal ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1
  end

  def test_save_bang_performs_put_if_match_raises_on_version_mismatch
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_header "If-Match", %|"#{@kv.ref}"|, env
      error_response(:version_mismatch)
    end
    assert_raises Orchestrate::API::VersionMismatch do
      @kv.save!
    end
  end

  def test_save_bang_performs_put_if_match_doesnt_raise_on_indexing_conflict
    ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      ref = make_ref
      assert_header "If-Match", %|"#{@kv.ref}"|, env
      error_response(:indexing_conflict, {
        headers: {"Location" => "/v0/items/#{@kv.key}/refs/#{ref}"},
        conflicts_uri: "/v0/items/#{@kv.key}/refs/#{ref}/conflicts"
      })
    end
    @kv.save!
    assert_equal ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1
  end

  def test_save_bang_performs_put_if_match_raises_on_request_error
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_header "If-Match", %|"#{@kv.ref}"|, env
      error_response(:bad_request)
    end
    assert_raises Orchestrate::API::BadRequest do
      @kv.save!
    end
  end

  def test_save_bang_performs_put_if_match_raises_on_service_error
    @stubs.put("/v0/items/#{@kv.key}") { error_response(:service_error) }
    assert_raises Orchestrate::API::ServiceError do
      @kv.save!
    end
  end

  def test_destroy_performs_delete_if_match_and_returns_true_on_success
    @stubs.delete("/v0/items/#{@kv.key}") do |env|
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      [204, response_headers, '']
    end
    assert_equal true, @kv.destroy
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1
  end

  def test_destroy_performs_delete_if_match_and_returns_false_on_error
    @stubs.delete("/v0/items/#{@kv.key}") { error_response(:version_mismatch) }
    assert_equal false, @kv.destroy
  end

  def test_destroy_bang_performs_delete_raises_on_error
    @stubs.delete("/v0/items/#{@kv.key}") { error_response(:version_mismatch) }
    assert_raises Orchestrate::API::VersionMismatch do
      @kv.destroy!
    end
  end

end
