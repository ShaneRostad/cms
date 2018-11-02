ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"
require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def signed_out_session
    { "rack.session" => { valid_user: true } }
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_file
    create_document "about.md"
    create_document "changes.txt", "some text"

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal "some text", last_response.body
  end

  def test_fake_file
    get "/notafile.txt"
    assert_equal 302, last_response.status
    assert_equal "notafile.txt does not exist", session[:message]

    get "/"
    refute_equal "notafile.txt does not exist", session[:message]
  end

  def test_content_type
    create_document "about.md"
    create_document "changes.txt"

    get "/work.md"
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    get "/changes.txt"
    assert_equal "text/plain", last_response["Content-Type"]
  end

  def test_editing_document
    create_document "about.md"
    create_document "changes.txt"

    get "/about.md/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    create_document "changes.txt"

    post "/changes.txt", {content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]
    #assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_new
    get "/new"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "a new document"
  end

  def test_view_new_document_form
    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_invalid_new_document
    post "/new", document: ""
    assert_equal 302, last_response.status

    assert_equal "A name is required", session[:message]
  end

  def test_new_document_creation
    post "/new", document: "doc.txt"
    assert_equal 302, last_response.status
    assert_equal "doc.txt was created", session[:message]
  end

  def test_delete_document
    create_document "text.txt"
    get "/text.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "text.txt has been deleted", session[:message]
    get last_response["Location"]
    get "/"
    refute_includes last_response.body, "text.txt"
  end

  def test_signin_page
    get "/signin"
    assert_includes last_response.body, "Username:"
    assert_equal 200, last_response.status
  end

  def test_signin
    post "/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    assert_equal "Welcome!", session[:message]
    get last_response["Location"]
    assert_includes last_response.body, "Signed-in as: admin"
  end

  def test_signin_with_bad_credentials
    post "/signin", username: "admin", password: "wrong"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    post "/signin", username: "admin", password: "secret"
    assert_equal "Welcome!", session[:message]

    get "/sign-out"
    assert_equal "You have been signed out.", session[:message]
  end

  def test_restricted_access
    get "/new"
    get last_response["Location"]
    assert_equal "You must be signed in to do that.", session[:message]
  end
end
