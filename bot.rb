require 'cinch'

class TriviaTicker
	include Cinch::Plugin

	def initialize(*args)
		super
	end

	timer 1, method: :tick
	def tick
		@bot.handlers.dispatch(:tick)
	end
end

class TriviaBot < Cinch::Bot

	def trivia_init
		load_questions
	end

	def load_questions
		@questions = []

		db = File.open('questions.txt','r');
		db.read.lines.each do |line|
			@questions << Hash[ [:question, :answer].zip( line.strip.split("\t") ) ]
		end
		db.close

		shuffle
	end
	
	def shuffle
		@question_idx = 0
		@questions.shuffle!
	end

	def start_game m
		return if @active

		@channel = m.channel
		start_question
		@active = true
	end

	def start_question
		next_question	
		Channel(@channel).send @question[:question]
	end

	def check_answer(m,t)
		return unless @active
		
		if t == @question[:answer]
			m.reply("Correct!")
			start_question
		end
	end

	def next_question
		shuffle if @question_idx >= @questions.length

		@question = @questions[@question_idx]
		@question_idx += 1
	end

	def tick
		return unless @active
	end
end

bot = TriviaBot.new do
	trivia_init

	configure do |c|
		c.nick = "derp"
		c.server = "irc.consental.com"
		c.verbose = true
		c.channels = ["#derp"]
		c.plugins.plugins = [TriviaTicker]
	end

	on :join do |m|
		#derp derp derp
	end

	on :channel, /^!start$/ do |m|
		bot.start_game m
	end

	on :channel, /^([^!].*)$/ do |m,t|
		bot.check_answer m,t
	end

	on :tick do
		bot.tick
	end

end

bot.start
