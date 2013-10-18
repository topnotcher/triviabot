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

class TriviaTaunter
	def initialize(bot)
		@bot = bot
		@idle = 0
	end

	def start_game
		reset_idle
	end

	def reset_idle
		@idle = 0
	end

	def tick
		return if @bot.active
		@idle += 1

		taunt if @idle >= 3600
	end
	
	def taunt
		reset_idle
		first = @bot.get_leaderboard.first

		if first
			@bot.chanmsg "%s is in first with %d points. You should !start a game and put him in his place!" % [first[:nick],first[:score]]
		else
			@bot.chanmsg "The leaderboard is empty. You should !start a game and grab first place!"
		end
	end
end

class TriviaStreak
	include Cinch::Helpers

	def initialize(bot)
		@bot = bot
	end

	def question_answered(nick)
		@streak ||= 0
		@nick ||= nick
		
		if @nick.downcase != nick.downcase
	
			if @streak and @streak >= 5
				@bot.chanmsg "%s broke %s's %d-answer streak!" % [nick, @nick, @streak]
			end

			@nick = nick
			@streak = 0
		end

		@streak += 1

		if @streak == 2 and rand(1) == 1
			@bot.chanact "hands %s beer!" % [nick]
		elsif @streak == 3
			msg = [ 
				"%s is on "+Format(:red,"FIRE!") ,
				"%s is on a ROLL.",
				"Congratulations, %s! That's your 3rd correct answer in a row.",
				"Great job, %s! Keep up the good work."
			].sample

			@bot.chanmsg msg % [nick]
		elsif @streak == 5
			@bot.chanmsg "%s is UNSTOPPABLE! (5)" % [nick]
		elsif @streak == 8
			@bot.chanmsg "Uhh... is anyone else playing, or is it just %s?!? (8)" % [nick]
		elsif @streak == 10
			@bot.chanmsg "%s is the TRIVIA MASTER. (10) " % [nick]
		elsif @streak > 10
			@bot.chanmsg "%s's streak continues: %d answers in a row!" % [nick, @streak]
		end
	end

	def question_timeout
		if @streak and @streak >= 5
			@bot.chanmsg "%s's reign of terror has ended!" % [@nick]
		end
	
		@nick = nil
		@streak = nil
	end
end

class TriviaHints
	include Cinch::Helpers
	def initialize(bot) 
		@bot = bot
	end

	def start_question
		@hint_count = 0
		@hint_str = nil
	end

	def unmask_hint
		idx = []

		(0..@hint_str.length).each do |i|
			idx << i if '*' == @hint_str[i]
		end
	
		return if idx.size <= 1

		unmask_count = idx.length/3
		unmask_count = 1 if unmask_count == 0
		idx.sample(unmask_count).each{|i| @hint_str[i] = get_answer[i]}
	end

	def get_answer
		@bot.question[:answer].first
	end

	def timeout_warn
		if @hint_count == 0 or not @hint_str
			@hint_str = get_answer.gsub(/[A-Za-z0-9]/, '*')
		else 
			unmask_hint
		end

		@hint_count += 1
		@bot.chanmsg "%s %d: %s" % [Format(:yellow, "Hint"), @hint_count, @hint_str]
	end
end

class TriviaBot < Cinch::Bot
	attr_reader	:question
	attr_reader :active

	def trivia_init
		@channel = '#derp'
		@question_time_limit = 60
		@question_warn_times = [45,30,15]

		@scores = []
		@trivia_plugins = [TriviaHints.new(self), TriviaStreak.new(self), TriviaTaunter.new(self)]
	end

	def get_score_entry(nick)
		entries = @scores.select {|entry| entry[:nick].downcase == nick.downcase}
		return nil if entries.empty?
		return entries.first
	end

	def add_score(nick,score)
		entry = get_score_entry(nick)

		unless entry	
			entry = {:nick => nick, :score => 0}
			@scores << entry
		end

		entry[:score] += score
	end

	def start_game m
		return if @active
		
		#@channel = m.channel
		start_question
		@timeout_count = 0
		@active = true

		fire_event :start_game
	end

	def get_leaderboard
		@scores.sort_by {|score| [-score[:score]]}
	end

	def stats(m)
		rank = 1
		get_leaderboard.each do |entry|
			m.reply("%d. %s %d" % [rank,entry[:nick],entry[:score]])
			rank+=1
		end
	end
	
	def repeat(m)
		return unless active_question?
		send_question
	end	

	def end_question
		@question = nil
	end

	def start_question_in n
		end_question
		@question_start_wait = n
	end

	def start_question_delay
		return unless @question_start_wait and @active
		@question_start_wait -= 1

		if @question_start_wait <= 0
			@question_start_wait = nil
			start_question
		end
	end

	def start_question
		next_question
		@question_time = @question_time_limit
		
		fire_event :start_question

		send_question
	end

	def fire_event(event,*args)
		@trivia_plugins.each do |mod|
			next unless mod.respond_to? event
			begin
				mod.send event, *args
			rescue
				#@todo log this
				puts $!,$@
			end
		end
	end

	def chanmsg(msg)
		Channel(@channel).send msg
	end

	def chanact(msg)
		Channel(@channel).action msg
	end

	def send_question
		chanmsg Format(:green, ">>> %s" % [@question[:question]])
	end

	# answer must have been normalized.
	def strip_leading_articles! a
		a.gsub!(/^(a|an|the) (.+)/,'\2')
	end

	def strip_trailing_plural! a
		a.gsub!(/([a-z]{4,})s$/,'\1')
	end

	def normalize_answer(a)
		norm = a.downcase

		# hyphens become spaces when surrounded by letters
		norm.gsub!(/([a-z])-([a-z])/, '\1 \2')

		norm.sub!(' & ', ' and ')

		norm.gsub!(/[^0-9a-z \-]/,'')
	
		# after removing symbols - it could have been rock 'n roll, but 
		# we'd also like to match rock and roll, but if it were written rockn roll? nah
		norm.sub!(' n ', ' and ')

		norm.gsub!(/[ ]+/, ' ')
	
		norm.strip!

		# so this is debatable, but...
		strip_leading_articles! norm
		strip_trailing_plural! norm
		return norm
	end

	def answers_match? a1,a2
		normalize_answer(a1) == normalize_answer(a2)
	end

	def check_answer(m,t)
		return unless active_question?
		@timeout_count = 0
		@question[:answer].each do |a|
			if answers_match?(t,a)
				@question[:answer].delete a if @kaos
				question_answered(m.user.nick,a)
				return
			end
		end
	end

	def question_answered(nick,answer)
		add_score nick, 1
		fire_event :question_answered, nick

		if @kaos
			remain = @question[:answer].size
			chanmsg "Good job, %s (%s)! %d answers remain." % [nick,answer,remain]
			start_question_in 10 if remain == 0
		else
			chanmsg "%s %s wins! '%s' was the answer." % [Format(:blue,"Correct!"), nick, answer]
			start_question_in 10
		end
	end

	def next_question
		File.open(Dir.glob('questions/*.txt').shuffle.first,'r') do |file| 
			questions = file.read

			pcs = questions.split("\n").shuffle.first.strip.split("\t")

			@question = Hash[ [:question, :answer].zip( [pcs.first, pcs.drop(1)] ) ]
		end

		if @question[:question].start_with? 'KAOS:'
			@kaos = true
		else
			@kaos = false
		end
	end

	def active_question?
		@active and @question
	end

	def check_question_time
		return unless active_question?

		@question_time -= 1
	
		if @question_time <= 0
			question_timeout
		elsif @question_warn_times.include? @question_time
			chanmsg "%s %d seconds remain..." % [Format(:yellow, '***'),@question_time]
			fire_event :timeout_warn
		end
	end

	def stop_game
		@active = false
	end

	def game_timeout 
		if @timeout_count >= 3
			chanmsg "Ending game after 3 consecutive timeouts!"
			end_question
			@active = false
			return true
		else
			return false
		end
	end

	def question_timeout
		chanmsg "%s The answer is: %s" % [Format(:red,'Timeout!'), Format(:green,@question[:answer].first)]
		@timeout_count += 1
		
		fire_event :question_timeout

		start_question_in 10 unless game_timeout
	end

	def tick
		fire_event :tick
		start_question_delay
		check_question_time
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

	on :channel, /^!stfu$/ do |m|
		bot.stop_game
	end

	on :channel, /^!repeat$/ do |m|
		bot.repeat m
	end

	on :channel, /^!stats$/ do |m|
		bot.stats m
	end

	on :channel, /^([^!].*)$/ do |m,t|
		bot.check_answer m,t
	end

	on :tick do
		bot.tick
	end

end

bot.start
