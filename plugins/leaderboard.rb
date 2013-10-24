module Trivia

class Leaderboard
	def initialize(bot,config)
		@bot = bot
		@stats_file = config[:statsfile]
		@scores = []

		load_saved_scores
	end

	def load_saved_scores
		return unless File.exists? @stats_file
		
		begin 
			@scores = YAML::load(File.open(@stats_file).read)
		# @todo log
		rescue
			@scores = []
		end
	end

	def save_scores
		begin
			File.open(@stats_file,'w') do |file|
				file.puts YAML::dump(@scores)
			end
		# @todo log
		rescue
			return
		end
	end

	def get_score_entry(nick)
		entries = @scores.select {|entry| entry[:nick].downcase == nick.downcase}
		return nil if entries.empty?
		return entries.first
	end

	def question_answered(nick)
		add_score nick,1
	end

	def add_score(nick,score)
		entry = get_score_entry(nick)

		unless entry	
			entry = {:nick => nick, :score => 0}
			@scores << entry
		end

		entry[:score] += score

		save_scores
	end

	def get_leaderboard
		@scores.sort_by {|score| [-score[:score]]}
	end

	def cmd_stats(m,argstr)
		rank = 1
		get_leaderboard.each do |entry|
			m.reply("%d. %s %d" % [rank,entry[:nick],entry[:score]])
			rank+=1
		end
	end
end
end
