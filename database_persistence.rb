require "pg"

class DatabasePersistence
  
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = <<~SQL
      SELECT        lists.id,
                    lists.name,
                    COUNT(todos.id) AS count_total,
                    COUNT(NULLIF(todos.completed, false)) AS count_completed
      FROM          lists
        LEFT JOIN   todos ON lists.id = todos.list_id
      WHERE         lists.id = $1
      GROUP BY      lists.id;
    SQL
    results = query(sql, id)
    tuple = results.first
    tuple_to_list_hash(tuple)
  end
    
  def all_lists
    sql = <<~SQL
      SELECT        lists.id,
                    lists.name, 
                    COUNT(todos.id) AS count_total,
                    COUNT(NULLIF(todos.completed, false)) AS count_completed 
      FROM          lists
        LEFT JOIN   todos ON lists.id = todos.list_id
      GROUP BY      lists.id;
    SQL
    results =query(sql)
    results.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = <<~SQL
      INSERT INTO lists (name)
        VALUES ($1);
    SQL
    query(sql, list_name)
  end

  def delete_list(id)
    sql = <<~SQL
      DELETE FROM lists
      WHERE id = $1;
    SQL
    query(sql, id)
    # @session[:lists].delete_at(id - 1)
  end

  def update_list_name(id, new_name)
    sql = <<~SQL
      UPDATE lists
      SET name = $1
      WHERE id = $2;
    SQL
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, new_name)
    sql = <<~SQL
      INSERT INTO todos (name, list_id)
      VALUES ($1, $2);
    SQL
    query(sql, new_name, list_id)
  end

  def delete_todo(list_id, todo_id)
    sql = <<~SQL
      DELETE FROM todos
      WHERE id = $1 AND list_id = $2;
    SQL
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = <<~SQL
      UPDATE todos
      SET completed = $1
      WHERE id = $2 AND list_id = $3;
    SQL
    query(sql, new_status, todo_id, list_id)
  end

  def todo_completed?(list_id, todo_id)
    sql = <<~SQL
      SELECT completed 
      FROM todos
      WHERE id = $1 AND list_id = $2;
    SQL
    results = query(sql, todo_id, list_id)
    results.values.flatten.first == 't'
  end

  def mark_all_complete(list_id)
    sql = <<~SQL
      UPDATE todos
      SET completed = true
      WHERE list_id = $1;
    SQL
    query(sql, list_id)
  end

  def load_todos(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1;"
    results = query(sql, list_id)
    results.map do |tuple|
      { id: tuple["id"], 
        name: tuple["name"], 
        completed: tuple["completed"] == 't'}
    end
  end

  private

  def tuple_to_list_hash(tuple)
  {
    id: tuple["id"], 
    name: tuple["name"], 
    count_total: tuple["count_total"].to_i, 
    count_completed: tuple["count_completed"].to_i, 
  }
  end
end
