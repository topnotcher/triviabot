module Trivia
class Streak
	include Cinch::Helpers

	def initialize(bot,config)
		@bot = bot
	end

	def question_answered(nick)
		@streak ||= 0
		@nick ||= nick
		
		if @nick.downcase != nick.downcase
	
			if @streak and @streak >= 5
				@bot.chanmsg "%s ended %s's reign of terror! (%d-answer streak)" % [nick, @nick, @streak]
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
			@bot.chanmsg "%s is UNSTOPPABLE!" % [nick]
		elsif @streak == 8
			@bot.chanmsg "Uhh... is anyone else playing, or is it just %s?!?" % [nick]
		elsif @streak == 10
			@bot.chanmsg "%s is the TRIVIA MASTER." % [nick]
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
end
