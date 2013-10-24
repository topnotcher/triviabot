module Trivia
class Taunter
	def initialize(bot,config)
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

		taunt if @idle >= 7200
	end

	def taunt
		reset_idle

		leaderboard = @bot.get_plugin(Leaderboard)

		return unless leaderboard

		first = leaderboard.get_leaderboard.first

		if first
			@bot.chanmsg "%s is in first with %d points. You should !start a game and put him in his place!" % [first[:nick],first[:score]]
		else
			@bot.chanmsg "The leaderboard is empty. You should !start a game and grab first place!"
		end
	end
end
end
