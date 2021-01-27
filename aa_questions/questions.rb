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

    def authored_replies
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM 
                replies
            JOIN
                users ON replies.author_id = users.id
            WHERE
                users.id = ?;
        SQL
        return nil if data.empty?
        data.map { |datum| Reply.new(datum) }
    end

    def followed_questions
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM
                questions
            JOIN question_follows
                ON question_follows.question_id = questions.id
            JOIN users
                ON users.id = question_follows.follower_id
            WHERE
                users.id = ?
        SQL
        return nil if data.empty?
        data.map {|datum| Question.new(datum)}
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

    def replies
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM
                replies
            WHERE
                replies.question_id = ?;
        SQL
        return nil if data.empty?
        data.map { |datum| Reply.new(datum) }
    end
end

class Reply
    attr_accessor :id, :body, :question_id, :parent_reply_id, :author_id

    def self.all
        data = QuestionsDatabase.instance.execute('SELECT * FROM replies')
        data.map { |datum| Reply.new(datum) }
    end

    def initialize(options)
        @id = options['id']
        @body = options['body']
        @question_id = options['question_id']
        @parent_reply_id = options['parent_reply_id']
        @author_id = options['author_id']
    end

    def create
        raise 'id already in use' if self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.body, self.question_id, self.parent_reply_id, self.author_id)
            INSERT INTO
                replies (body, question_id, parent_reply_id, author_id)
            VALUES
                (?, ?, ?, ?)
        SQL
        self.id = QuestionsDatabase.instance.last_insert_row_id
    end

    def update
        raise 'id not valid' unless self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.body, self.question_id, self.parent_reply_id, self.author_id, self.id)
            UPDATE
                replies
            SET
                body = ?, question_id = ?, parent_reply_id = ?, author_id = ?
            WHERE
                id = ?;
        SQL
    end

    def self.find_by_author_id(author_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
            SELECT
                *
            FROM
                replies
            WHERE 
                author_id = ?;
        SQL
        data.map {|datum| Reply.new(datum)}
    end 

    def self.find_by_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT
                *
            FROM
                replies
            WHERE 
                question_id = ?;
        SQL
        data.map {|datum| Reply.new(datum)}
    end

    def author
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM
                users
            JOIN 
                replies ON replies.author_id = users.id
            WHERE
                replies.id = ?;
        SQL
        author = data.map {|datum| User.new(datum)}
        author.first
    end 

    def question
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM
                questions
            JOIN 
                replies ON replies.question_id = questions.id
            WHERE
                replies.id = ?;
        SQL
        question = data.map {|datum| Question.new(datum)}
        question.first
    end 

    def parent_reply
        data = QuestionsDatabase.instance.execute(<<-SQL, self.parent_reply_id)
            SELECT
                *
            FROM
                replies
            WHERE
                replies.id = ?;
        SQL
        return nil if data.empty?
        data.map { |datum| Reply.new(datum) }[0]
    end

    def child_replies
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                *
            FROM
                replies
            WHERE
                replies.parent_reply_id = ?;
        SQL
        return nil if data.empty?
        data.map { |datum| Reply.new(datum) }
    end
end 

class QuestionFollow
    attr_accessor :id, :question_id, :follower_id

    def self.all
        data = QuestionsDatabase.instance.execute('SELECT * FROM question_follows')
        data.map { |datum| QuestionFollow.new(datum) }
    end

    def initialize(options)
        @id = options['id']
        @question_id = options['question_id']
        @follower_id = options['follower_id']
    end

    def create
        raise 'id already in use' if self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.question_id, self.follower_id)
            INSERT INTO
                question_follows (question_id, follower_id)
            VALUES
                (?, ?)
        SQL
        self.id = QuestionsDatabase.instance.last_insert_row_id
    end

    def update
        raise 'id not valid' unless self.id
        QuestionsDatabase.instance.execute(<<-SQL, self.question_id, self.follower_id, self.id)
            UPDATE
                question_follows
            SET
                question_id = ?, follower_id = ?
            WHERE
                id = ?;
        SQL
    end

    def self.followers_for_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT
                *
            FROM
                users
            JOIN question_follows
                ON users.id = question_follows.follower_id
            WHERE
                question_follows.question_id = ?
        SQL
        return nil if data.empty?
        data.map {|datum| User.new(datum)}
    end 

    def self.followed_question_for_follower_id(follower_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, follower_id)
            SELECT
                *
            FROM
                questions
            JOIN question_follows
                ON questions.id = question_follows.question_id
            WHERE
                question_follows.follower_id = ?
        SQL
        return nil if data.empty?
        data.map {|datum| Question.new(datum)}
    end 
end 