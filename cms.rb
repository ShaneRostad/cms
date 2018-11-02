require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'pass'
  #set :erb, :escape_html => true
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# before do
#
# end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

before do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
end

def valid_login?(username, password)
  username == "admin" && password == "secret"
end

get "/" do
  erb :index
end

get "/signin" do
  erb :sign_in
end

post "/signin" do
  if params[:username] == "admin" && params[:password] == "secret"
    session[:username] = params[:username]
    session[:valid_user] = true
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :sign_in
  end
end

def check_if_logged_in
  if session[:valid_user] == false || session[:valid_user] == nil
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/sign-out" do
  session[:valid_user] = false
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/new" do
  check_if_logged_in
  erb :new_file
end

post "/new" do
  check_if_logged_in

  if params[:document] == ""
    session[:message] = "A name is required"
    redirect "/new"
  end

  file = File.open("#{data_path}/#{params[:document]}", "w")
  @files << file
  session[:message] = "#{params[:document]} was created"
  redirect "/"
end

get "/:file_name" do
  file_path = File.join(data_path, params[:file_name])
  @file = params[:file_name]

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:file_name]} does not exist"
    redirect "/"
  end
end

get "/:file_name/edit" do
  check_if_logged_in

  file_path = File.join(data_path, params[:file_name])

  @file = params[:file_name]
  @content = File.read(file_path)

  erb :edit_file
end


post "/:file_name" do
  check_if_logged_in
  file_path = File.join(data_path, params[:file_name])

  File.write(file_path, params[:content])
  #File.write("data/#{@file}", params[:content])

  session[:message] = "#{params[:file_name]} has been updated."
  redirect "/"
end

get "/:file_name/delete" do
  check_if_logged_in

  file_path = File.join(data_path, params[:file_name])
  File.delete(file_path)
  session[:message] = "#{params[:file_name]} has been deleted"
  redirect "/"
end
