# frozen_string_literal: true

module Make
  class Plot
    PLOT_SIZE = '1280,800'

    def self.all(**options)
      uk(**options)
      scotland(**options)
      health_boards(**options)
      mobility_regions(**options)
      nil
    end

    def self.health_boards(**options)
      ScotlandCovid19Data.health_boards.each do |health_board|
        health_board health_board, **options
        health_board_comparison health_board, **options
      end
      nil
    end

    def self.scotland(**options)
      scotland_cases_by_health_board(**options)
      scotland_cases_by_health_board_smoothed(**options)
      scotland_deaths_by_health_board(**options)
      scotland_icus(**options)
      scotland_icu_deceased(**options)
      country_comparison('Scotland', **options)
      mobility('Scotland', **options)
      mobility_comparison('Scotland', **options)
    end

    def self.scotland_cases_by_health_board(**options)
      $logger.info 'Plotting cases by health board data for Scotland.'
      health_boards = ScotlandCovid19Data.health_boards
      data = Make::Data.scotland_cases_by_health_board.transpose

      basic_plot(**options, filename: "scotland_total_cases_per_#{NUMBERS_PER}.png") do |plot|
        plot.title "Scottish Health Board Total COVID-19 Cases (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')})"
        plot.logscale 'y 10'

        data[1..-2].each.with_index do |this_data, index|
          plot.add_data Gnuplot::DataSet.new([data[0], this_data]) { |ds|
            ds.using = '1:2'
            ds.with = 'line'
            ds.title = health_boards[index]
          }
        end
      end
    end

    def self.scotland_cases_by_health_board_smoothed(**options)
      $logger.info 'Plotting smoothed cases by health board data for Scotland.'
      health_boards = ScotlandCovid19Data.health_boards

      data = Array.new(15) { Array.new }                                  # date, 14 health boards
      Make::Data.scotland_cases_by_health_board.each_cons(7) do |records| # each record is date, 14 health boards
        data[0].push records.last[0]
        (1..14).each do |i|
          data[i].push records.last[i].to_f - records.first[i].to_f
        end
      end

      basic_plot(**options, filename: "scotland_daily_cases_per_#{NUMBERS_PER}_averaged_7_days.png") do |plot|
        plot.title "Scottish Health Board Daily COVID-19 Cases (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')}, 7 day rolling average)"

        data[1..-2].each.with_index do |this_data, index|
          plot.add_data Gnuplot::DataSet.new([data[0], this_data]) { |ds|
            ds.using = '1:2'
            ds.with = 'line'
            ds.title = health_boards[index]
          }
        end
      end
    end

    def self.scotland_deaths_by_health_board(**options)
      $logger.info 'Plotting deaths by health board data for Scotland.'
      health_boards = ScotlandCovid19Data.health_boards
      data = Make::Data.scotland_deaths_by_health_board.transpose

      basic_plot(**options, filename: "scotland_total_deaths_per_#{NUMBERS_PER}.png") do |plot|
        plot.title "Scottish Health Board Total COVID-19 Deaths (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')})"
        plot.logscale 'y 10'

        data[1..-2].each.with_index do |this_data, index|
          plot.add_data Gnuplot::DataSet.new([data[0], this_data]) { |ds|
            ds.using = '1:2'
            ds.with = 'line'
            ds.title = health_boards[index]
          }
        end
      end
    end

    def self.scotland_icus(**options)
      $logger.info 'Plotting icu beds by health board data for Scotland.'
      health_boards = [*ScotlandCovid19Data.health_boards, 'The Golden Jubilee National Hospital']
      data = Make::Data.scotland_icus.transpose

      basic_plot(**options, filename: 'scotland_icus.png') do |plot|
        plot.title 'Scottish Health Board COVID-19 ICU Beds'

        data[1..-2].each.with_index do |this_data, index|
          plot.add_data Gnuplot::DataSet.new([data[0], this_data]) { |ds|
            ds.using = '1:2'
            ds.with = 'line'
            ds.title = health_boards[index]
          }
        end
      end
    end

    def self.scotland_icu_deceased(**options)
      $logger.info 'Plotting deceased and ICU data for Scotland.'
      data = Make::Data.scotland_icu_deceased.transpose

      basic_plot(**options, filename: 'scotland_icu_deceased.png') do |plot|
        plot.title 'Scottish COVID-19 Cumulative Deceased and Intensive Care Use'
        plot.logscale 'y 10'

        plot.add_data Gnuplot::DataSet.new([data[0], data[1]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Patients in intensive care'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[2]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Cumulative deceased'
        }
      end
    end

    def self.health_board(name, **options)
      fail "#{name.inspect} is not a known health board" unless ScotlandCovid19Data.health_boards.include?(name)

      $logger.info "Plotting health board data for #{name}."
      dates, cases, deaths = Make::Data.health_board(name).transpose
      daily_cases = []
      cases.each_cons(2) { |a, b| daily_cases.push b.to_f - a.to_f }

      if [cases.reject(&:nil?).max, deaths.reject(&:nil?).max].all?(0.0)
        $logger.debug "#{name} has no cases."
        if options[:target] && options[:target] != :file
          return "#{name} has no cases."
        else
          FileUtils.copy(
            File.join(ROOT_DIR, 'template', 'no_cases.png'),
            File.join(PUBLIC_DIR, "#{name.downcase.gsub(' ', '_')}_per_#{NUMBERS_PER}.png")
          )
        end
        return
      end

      basic_plot(**options, filename: "#{name.downcase.gsub(' ', '_')}_per_#{NUMBERS_PER}.png") do |plot|
        plot.title "COVID-19 in #{name} (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')})"
        plot.logscale 'y 10'
        plot.ytics 'nomirror'
        plot.set 'ylabel "Total" offset 2'

        plot.y2range '[0:]'
        plot.y2tics 'nomirror'
        plot.set 'y2label "Daily" offset -2'

        plot.add_data Gnuplot::DataSet.new([dates[1..-1], daily_cases]) { |ds|
          ds.axes = 'x1y2'
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Daily Cases'
          ds.linewidth = 1
          ds.linecolor = 'rgb "#9400d3"'
        }

        plot.add_data Gnuplot::DataSet.new([dates, cases]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Total Cases'
          ds.linewidth = 2
          ds.linecolor = 'rgb "#9400d3"'
        }

        plot.add_data Gnuplot::DataSet.new([dates, deaths]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Total Deaths'
          ds.linewidth = 2
          ds.linecolor = 'rgb "#009e73"'
        }
      end
    end

    def self.health_board_comparison(name, **options)
      fail "#{name.inspect} is not a known health board" unless ScotlandCovid19Data.health_boards.include?(name)

      $logger.info "Plotting #{name} vs Scotland data."
      data = Make::Data.health_board(name).transpose

      comparrison_plot(**options, filename: "#{name.downcase.gsub(' ', '_')}_vs_scotland.png") do |plot|
        plot.title "COVID-19 in #{name} vs Scotland"
        plot.ylabel "#{name} per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')} ÷ Scotland per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')}"

        plot.add_data Gnuplot::DataSet.new([data[0], data[3]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Cases'
          ds.linewidth = 2
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[4]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Deaths'
          ds.linewidth = 2
        }
      end
    end

    def self.uk(**options)
      uk_total_cases_by_country(**options)
      uk_total_deaths_by_country(**options)
      uk_daily_cases_by_country(**options)
      uk_daily_deaths_by_country(**options)
      uk_daily_cases_by_country_smoothed(**options)
      uk_daily_deaths_by_country_smoothed(**options)
      country_comparison('England', **options)
      country_comparison('Scotland', **options)
      country_comparison('Wales', **options)
      country_comparison('Northern Ireland', **options)
      mobility('UK', **options)
    end

    def self.uk_total_cases_by_country(**options)
      $logger.info 'Plotting total cases by country data for UK.'
      data = Make::Data.uk_cases.transpose

      basic_plot(**options, filename: "uk_total_cases_per_#{NUMBERS_PER}.png") do |plot|
        plot.title "UK COVID-19 Total Cases (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')})"
        plot.logscale 'y 10'

        plot.add_data Gnuplot::DataSet.new([data[0], data[1]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'England'
          ds.linewidth = 2
          ds.linecolor = 'rgb "red"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[2]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Scotland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "blue"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[3]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Wales'
          ds.linewidth = 2
          ds.linecolor = 'rgb "green"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[4]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Northern Ireland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "cyan"'
        }
      end
    end

    def self.uk_daily_cases_by_country(**options)
      $logger.info 'Plotting daily cases by country data for UK.'
      data = Make::Data.uk_cases.transpose

      basic_plot(**options, filename: "uk_daily_cases_per_#{NUMBERS_PER}.png") do |plot|
        plot.title "UK COVID-19 Daily Cases (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')})"

        plot.add_data Gnuplot::DataSet.new([data[0], data[6]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'England'
          ds.linewidth = 2
          ds.linecolor = 'rgb "red"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[7]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Scotland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "blue"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[8]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Wales'
          ds.linewidth = 2
          ds.linecolor = 'rgb "green"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[9]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Northern Ireland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "cyan"'
        }
      end
    end

    def self.uk_daily_cases_by_country_smoothed(**options)
      $logger.info 'Plotting smoothed daily cases by country data for UK.'
      data = [[], [], [], [], []]                   # date, England, Scotland, Wales, Northern Ireland
      Make::Data.uk_cases.each_cons(7) do |records| # each record is date, 5 totals, 5 dailies
        data[0].push records.last[0]
        (1..4).each do |i|
          data[i].push records.map { |r| r[i + 5].to_f }.sum / records.count
        end
      end

      basic_plot(**options, filename: "uk_daily_cases_per_#{NUMBERS_PER}_averaged_7_days.png") do |plot|
        plot.title "UK COVID-19 Daily Cases (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')}, 7 day rolling average)"

        plot.add_data Gnuplot::DataSet.new([data[0], data[1]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'England'
          ds.linewidth = 2
          ds.linecolor = 'rgb "red"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[2]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Scotland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "blue"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[3]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Wales'
          ds.linewidth = 2
          ds.linecolor = 'rgb "green"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[4]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Northern Ireland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "cyan"'
        }
      end
    end

    def self.uk_total_deaths_by_country(**options)
      $logger.info 'Plotting total deaths by country data for UK.'
      data = Make::Data.uk_deaths.transpose

      basic_plot(**options, filename: "uk_total_deaths_per_#{NUMBERS_PER}.png") do |plot|
        plot.title "UK COVID-19 Total Deaths (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')})"
        plot.logscale 'y 10'

        plot.add_data Gnuplot::DataSet.new([data[0], data[1]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'England'
          ds.linewidth = 2
          ds.linecolor = 'rgb "red"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[2]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Scotland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "blue"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[3]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Wales'
          ds.linewidth = 2
          ds.linecolor = 'rgb "green"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[4]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Northern Ireland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "cyan"'
        }
      end
    end

    def self.uk_daily_deaths_by_country(**options)
      $logger.info 'Plotting daily deaths by country data for UK.'
      data = Make::Data.uk_deaths.transpose

      basic_plot(**options, filename: "uk_daily_deaths_per_#{NUMBERS_PER}.png") do |plot|
        plot.title "UK COVID-19 Daily Deaths (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')})"

        plot.add_data Gnuplot::DataSet.new([data[0], data[6]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'England'
          ds.linewidth = 2
          ds.linecolor = 'rgb "red"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[7]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Scotland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "blue"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[8]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Wales'
          ds.linewidth = 2
          ds.linecolor = 'rgb "green"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[9]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Northern Ireland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "cyan"'
        }
      end
    end

    def self.uk_daily_deaths_by_country_smoothed(**options)
      $logger.info 'Plotting smoothed daily deaths by country data for UK.'
      data = [[], [], [], [], []]                     # date, England, Scotland, Wales, Northern Ireland
      Make::Data.uk_deaths.each_cons(7) do |records|  # each record is date, 5 totals, 5 dailies
        data[0].push records.last[0]
        (1..4).each do |i|
          data[i].push records.map { |r| r[i + 5].to_f }.sum / records.count
        end
      end

      basic_plot(**options, filename: "uk_daily_deaths_per_#{NUMBERS_PER}_averaged_7_days.png") do |plot|
        plot.title "UK COVID-19 Daily Deaths (per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')}, 7 day rolling average)"

        plot.add_data Gnuplot::DataSet.new([data[0], data[1]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'England'
          ds.linewidth = 2
          ds.linecolor = 'rgb "red"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[2]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Scotland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "blue"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[3]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Wales'
          ds.linewidth = 2
          ds.linecolor = 'rgb "green"'
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[4]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Northern Ireland'
          ds.linewidth = 2
          ds.linecolor = 'rgb "cyan"'
        }
      end
    end

    def self.country_comparison(name, **options)
      unless ['England', 'Scotland', 'Wales', 'Northern Ireland'].include?(name)
        fail "#{name.inspect} is not a known country"
      end

      $logger.info "Plotting #{name} vs UK data."
      data = Make::Data.country(name).transpose

      comparrison_plot(**options, filename: "#{name.downcase.gsub(' ', '_')}_vs_uk.png") do |plot|
        plot.title "COVID-19 in #{name} vs the UK"
        plot.ylabel "#{name} per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')} ÷ UK per #{NUMBERS_PER.to_s.gsub(/\B(?=(...)*\b)/, ',')}"

        plot.add_data Gnuplot::DataSet.new([data[0], data[3]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Cases'
          ds.linewidth = 2
        }

        plot.add_data Gnuplot::DataSet.new([data[0], data[4]]) { |ds|
          ds.using = '1:2'
          ds.with = 'line'
          ds.title = 'Deaths'
          ds.linewidth = 2
        }
      end
    end

    def self.mobility(region, **options)
      $logger.info "Plotting #{region} mobility data."
      titles = ['Retail \& recreation', 'Grocery \& pharmacy', 'Parks', 'Transit stations', 'Workplaces', 'Residential']
      data = Make::Data.mobility[region].transpose

      basic_plot(**options, filename: "mobility_#{region.downcase}.png", yrange: nil) do |plot|
        plot.title "Mobility in #{region}"
        plot.ylabel 'Usage compared to pre pandemic levels (%)'

        plot.add_data Gnuplot::DataSet.new('0') { |ds|
          ds.linewidth = 1
          ds.title = ''
          ds.linecolor = 'rgb "black"'
        }

        titles.each_with_index do |title, i|
          plot.add_data Gnuplot::DataSet.new([data[0], data[i+1]]) { |ds|
            ds.using = '1:2'
            ds.with = 'line'
            ds.title = title
            ds.linewidth = 2
          }
        end
      end
    end

    def self.mobility_regions(**options)
      $logger.info 'Plotting regions mobility data.'
      titles = ['Retail \& recreation', 'Grocery \& pharmacy', 'Parks', 'Transit stations', 'Workplaces', 'Residential']
      data = Make::Data.mobility
      regions = data.keys - [nil, 'UK', 'Scotland']

      regions.each do |region|
        region_data = data[region].transpose

        basic_plot(**options, filename: "mobility_#{region.downcase.gsub(' ', '_')}.png", yrange: nil) do |plot|
          plot.title "Mobility in #{region}"
          plot.ylabel 'Usage compared to pre pandemic levels (%)'

          plot.add_data Gnuplot::DataSet.new('0') { |ds|
            ds.linewidth = 1
            ds.title = ''
            ds.linecolor = 'rgb "black"'
          }

          titles.each_with_index do |title, i|
            plot.add_data Gnuplot::DataSet.new([region_data[0], region_data[i+1]]) { |ds|
              ds.using = '1:2'
              ds.with = 'line'
              ds.title = title
              ds.linewidth = 2
            }
          end
        end
      end
    end

    def self.mobility_comparison(region, **options)
      $logger.info "Plotting #{region} vs UK mobility data."
      titles = ['Retail \& recreation', 'Grocery \& pharmacy', 'Parks', 'Transit stations', 'Workplaces', 'Residential']
      data_uk = Make::Data.mobility_uk.group_by(&:first)
      data_reg = Make::Data.mobility[region]
      data = []
      data_reg.map do |date, *reg|
        next unless data_uk.key?(date)

        uk = data_uk[date].first[1..-1]
        data.push [date, (reg[0]&.-(uk[0].to_i)), (reg[1]&.-(uk[1].to_i)), (reg[2]&.-(uk[2].to_i)), (reg[3]&.-(uk[3].to_i)), (reg[4]&.-(uk[4].to_i)), (reg[5]&.-(uk[5].to_i))]
      end
      data = data.transpose

      basic_plot(**options, filename: "mobility_#{region.downcase}_vs_uk.png", yrange: nil) do |plot|
        plot.title "Mobility in #{region} vs the UK"

        plot.add_data Gnuplot::DataSet.new('0') { |ds|
          ds.linewidth = 1
          ds.title = ''
          ds.linecolor = 'rgb "black"'
        }

        titles.each_with_index do |title, i|
          plot.add_data Gnuplot::DataSet.new([data[0], data[i+1]]) { |ds|
            ds.using = '1:2'
            ds.with = 'line'
            ds.title = title
            ds.linewidth = 2
          }
        end
      end
    end

    class << self
      private

      def basic_plot(target: :file, filename: nil, yrange: '[0:]')
        Gnuplot.open do |gp|
          Gnuplot::Plot.new(gp) do |plot|
            case target
            when :file
              fail ArgumentError, 'filename must be passed when target is :file' unless filename
              plot.terminal "pngcairo size #{PLOT_SIZE}"
              plot.output File.join(PUBLIC_DIR, filename)
            when :screen
              plot.terminal "wxt size #{PLOT_SIZE} persist"
            else
              fail "#{target.inspect} is not a valid target."
            end

            plot.xdata 'time'
            plot.timefmt '\'%Y-%m-%d\''
            plot.format 'x \'%d/%m/%y\''
            plot.xrange "['#{Date.new(2020, 2, 17)}':'#{Date.today}']"

            plot.yrange yrange if yrange

            plot.key 'outside center bottom horizontal'
            plot.grid

            yield plot
          end
        end
        nil
      end

      def comparrison_plot(**options)
        basic_plot(**options) do |plot|
          plot.add_data Gnuplot::DataSet.new('1') { |ds|
            ds.linewidth = 1
            ds.title = ''
          }

          yield plot
        end
        nil
      end
    end
  end
end
