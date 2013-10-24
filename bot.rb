require 'yaml'
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
	attr_reader	:question
	attr_reader :active

	def trivia_init
		
		@trivia_plugins = []

		load_config
	end

	def load_config
		@trivia_config = YAML::load(File.open('bot.yaml'))

		plugins_config = @trivia_config.delete(:plugins)
		init_plugins(plugins_config) if plugins_config
	end

	def init_plugins(config) 
		config.each do |plugin|
			init_plugin(plugin)
		end
	end
	
	def init_plugin(plugin_config)
		name = plugin_config[:class]

		require_relative 'plugins/'+name.downcase
			
		@trivia_plugins << Trivia::const_get(name).new(@bot, plugin_config[:config])
	end

	def handle_cmd(m, cmd, argstr)

		fire_event 'cmd_'+cmd, m, argstr

		if cmd == 'start'
			start_game m
		elsif cmd == 'repeat'
			repeat m
		elsif cmd == 'stfu'
			stop_game
		end
	end

	def start_game m
		return if @active
		
		#@channel = m.channel
		start_question
		@timeout_count = 0
		@active = true

		fire_event :start_game
	end

	def get_plugin(type)
		@trivia_plugins.each do |plugin|
			return plugin if plugin.class == type
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
		@question_time = @trivia_config[:question_time_limit]
		
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
		Channel(@trivia_config[:channel]).send msg
	end

	def chanact(msg)
		Channel(@trivia_config[:channel]).action msg
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
		elsif @trivia_config[:question_warn_times].include? @question_time
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
		c.nick = @trivia_config[:nick]
		c.server = @trivia_config[:host]
		c.verbose = true
		c.channels = [@trivia_config[:channel]]
		c.plugins.plugins = [TriviaTicker]
	end

	on :join do |m|
		#derp derp derp
	end

	on :channel, /^!([A-Za-z0-9_\-]+)(?: (.+))?$/ do |m,cmd,argstr|
		bot.handle_cmd m, cmd, argstr
	end

	on :channel, /^([^!].*)$/ do |m,t|
		bot.check_answer m,t
	end

	on :tick do
		bot.tick
	end

end

bot.start
