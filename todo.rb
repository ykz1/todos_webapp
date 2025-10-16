require "sinatra"
require "sinatra/content_for"
require "tilt/erubi"
require_relative "database_persistence"


configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, SecureRandom.hex(32) # this hardcodes our session secret to maintain the same session over app reloads
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

# view helpers

helpers do
  def completion_progress(list)
    todos_count = list[:todos].count
    todos_completed = list[:todos].count { |todo| todo[:completed] }
    "#{todos_completed} / #{todos_count}"
  end

  def all_completed?(list)
    list[:todos].count > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    return "complete" if all_completed?(list)
    ""
  end

  def sort_lists(lists, &block)
    lists.each { |list| yield(list) if !all_completed?(list) }
    lists.each { |list| yield(list) if all_completed?(list) }
  end

  def sort_todos(todos)
    todos.each { |todo| yield(todo) if !todo[:completed] }
    todos.each { |todo| yield(todo) if todo[:completed] }
  end
end

# Helper methods

def load_list(list_id)
  list = @storage.find_list(list_id)
  return list if list
  
  session[:error] = "List not found."
  redirect '/lists'
end

# Return error message if form invalid, otherwise return nil
def error_for_list_name(name)
  return "List name must be between 1 and 100 characters." if !(1..100).cover? name.size
  return "List name must be unique." if @storage.all_lists.any? { |list| list[:name] == name }
  nil
end

# Validate todo item
def error_for_todo_item(name, list)
  return "Todo name must be between 1 and 100 characters." if !(1..100).cover? name.size
  nil
end

before do
  @storage = DatabasePersistence.new(logger)
end

get '/' do
  redirect '/lists'
end

# not_found do
#   redirect '/'
# end

# =================================
# ROUTES
#
# GET   /lists      -> View all lists
# GET   /lists/new  -> New list form
# POST  /lists      -> Create new list
# GET   /lists/1    -> view a single list



# View all lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists/new' do
  list_name = params[:list_name].strip

  error_message = error_for_list_name(list_name)

  if error_message
    session[:error] = error_message
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)

    session[:success] = "The list has been created."
    redirect '/lists'
  end
end

# View single list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit list name
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Submit new list name
post "/lists/:list_id/edit" do
  @list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  error_message = error_for_list_name(@list_name)

  if error_message
    session[:error] = error_message
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, @list_name)
    session[:success] = "The list name has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Add new todo
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_name = params[:todo_item].strip

  error_message = error_for_todo_item(todo_name, @list)
  
  if error_message
    session[:error] = error_message
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, todo_name)
    session[:success] = "Todo item added!"
    redirect "/lists/#{@list_id}"
  end
end

# Delete list
post "/lists/:list_id/delete" do
  @storage.delete_list(params[:list_id].to_i)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "List deleted"
    redirect "/lists"
  end
end

# Delete a todo
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @storage.delete_todo(@list_id, todo_id)
  @list[:todos].delete_if { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Todo has been deleted."
    redirect "/lists/#{params[:list_id]}"
  end
end

# Update status of a todo
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  new_status = params[:completed] == 'true'
  @storage.update_todo_status(@list_id, todo_id, new_status)

  session[:success] = @storage.todo_completed?(@list_id, todo_id) ? "Todo checked." : "Todo unchecked."

  redirect "/lists/#{@list_id}"
end

# Complete all todos
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_complete(@list_id)
  session[:success] = "All todos marked completed."

  redirect "/lists/#{@list_id}"
end