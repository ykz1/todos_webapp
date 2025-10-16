class SessionPersistence
  
  def initialize(session)
    @session = session
    @session[:lists] ||= [] # makes sure that session[:lists] is never nil
  end

  def find_list(id)
    @session[:lists].find { |list | list[:id] == id }
  end
  
  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_id(all_lists)
    @session[:lists] << {id: id, name: list_name, todos: []}
  end

  def next_id(array)
    max = array.map { |object| object[:id] }.max || 0
    max + 1
  end

  def delete_list(id)
    @session[:lists].delete_at(id - 1)
  end

  def error
    @session[:error]
  end

  def error=(msg)
    @session[:error] = msg
  end

  def delete_error
    @session.delete(:error)
  end

  def success=(msg)
    @session[:success] = msg
  end

  def success
    @session[:success]
  end

  def delete_success
    @session.delete(:success)
  end

  def update_list_name(id, new_name)
    list = find_list(id)
    list[:name] = new_name
  end

  def create_new_todo(list_id, new_name)
    list = find_list(list_id)
    id = next_id(list[:todos])
    list[:todos] << { id: id, name: new_name, completed: false }
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed] = (new_status)
  end
  def todo_completed?(list_id, todo_id)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed]
  end

  def mark_all_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end
end
