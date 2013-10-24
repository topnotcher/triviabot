module Trivia

class Hints
	include Cinch::Helpers
	def initialize(bot,config)
		@bot = bot
	end

	def start_question
		@hint_count = 0
		@hint_str = nil
		@hint_str = get_answer.gsub(/[A-Za-z0-9]/, '*')
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

	def cmd_hint m, argstr
		send_hint
	end

	def timeout_warn
		unmask_hint if @hint_count > 0
		@hint_count += 1
		send_hint
	end 

	def send_hint
		@bot.chanmsg "%s %d: %s" % [Format(:yellow, "Hint"), @hint_count, @hint_str]
	end
end

end
