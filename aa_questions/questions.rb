require 'sqlite3'
require 'singleton'

# SQLite3::Database.new( "data.db" ) do |db|
#     db.execute( "select * from table" ) do |row|
#       p row
#     end
#   end

class QuestionsDatabase < SQLite3::Database
    include Singleton 

    def initialize
        super('questions.db')
        self.type_translation = true
        self.results_as_hash = true
    end
end

class User
    attr_accessor :id, :fname, :lname

    def self.all
        data = QuestionsDatabase.instance.execute('SELECT * FROM users')
        data.map { |datum| User.new(datum) }
    end

    def initialize(options)
        @id = options['id']
        @fname = options['fname']
        @lname = options['lname']
    end

    def create
        raise 'id already in use' if self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.fname, self.lname)
            INSERT INTO
                users (fname, lname)
            VALUES
                (?, ?)
        SQL
        self.id = QuestionsDatabase.instance.last_insert_row_id
    end

    def update
        raise 'id not valid' unless self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.fname, self.lname, self.id)
            UPDATE
                users
            SET
                fname = ?, lname = ?
            WHERE
                id = ?;
        SQL
    end

    def self.find_by_name(fname, lname)
        data = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
            SELECT
                *
            FROM
                users
            WHERE 
                fname = ? AND
                lname = ?
        SQL
        return nil if data.empty?
        data.map { |datum| User.new(datum) }
    end 

    def authored_questions
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM 
                questions
            JOIN
                users ON questions.author_id = users.id
            WHERE
                users.id = ?;
        SQL
        return nil if data.empty?
        data.map { |datum| Question.new(datum) }
    end
end

class Question
    attr_accessor :id, :title, :body, :author_id

    def self.all
        data = QuestionsDatabase.instance.execute('SELECT * FROM questions')
        data.map { |datum| Question.new(datum) }
    end

    def initialize(options)
        @id = options['id']
        @title = options['title']
        @body = options['body']
        @author_id = options['author_id']
    end

    def create
        raise 'id already in use' if self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.title, self.body, self.author_id)
            INSERT INTO
                questions (title, body, author_id)
            VALUES
                (?, ?, ?)
        SQL
        self.id = QuestionsDatabase.instance.last_insert_row_id
    end

    def update
        raise 'id not valid' unless self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.title, self.body, self.author_id, self.id)
            UPDATE
                questions
            SET
                title = ?, body = ?, author_id = ?
            WHERE
                id = ?;
        SQL
    end

    def self.find_by_author_id(author_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
            SELECT
                *
            FROM
                questions
            WHERE
                author_id = ?;
        SQL
        return nil if data.empty?
        data.map { |datum| Question.new(datum) }
    end

    def author
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM
                users
            JOIN
                questions ON users.id = questions.author_id
            WHERE
                questions.id = ?;
        SQL
        User.new(data.first)
    end
end