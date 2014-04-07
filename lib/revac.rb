# encoding: utf-8
require 'CSV'

# Implements the REVAC tuning method (Relevance Estimation and Value
# Calibration of Evolutionary Algorithm Parameters), proposed by Nannen and
# Eiben, which provides a fast and rational approach to parameter tuning for
# meta-heuristics.
#
# Although originally designed for finding the optimal parameter setup for
# evolutionary algorithms, this REVAC implementation may also be used to
# tune other meta-heuristics, such as Ant Colony Optimisation or Particle
# Swarm Optimisation.
module REVAC

  # Used to hold the name and range of legal values for a search parameter.
  Parameter = Struct.new(:name, :range)

  # Logs a parameter vector and its associated utility function value using
  # a given CSV file.
  #
  # ==== Parameters
  # [+path+]        The path to the output JSON file.
  # [+evaluation+]  The current evaluation.
  # [+vector+]      The parameter vector table.
  # [+utility+]     The utility of the given vector.
  def self.log(path, evaluation, vector, utility)
    CSV.open(path, 'ab') do |f|
      f << [evaluation] + vector + [utility]
    end
  end

  # Computes the utility (response) of a given parameter vector.
  #
  # ==== Parameters
  # [+vector+]      The parameter vector to evaluate.
  # [+parameters+]  The list of tunable parameters.
  # [+algorithm+]   A function which takes the a hash of parameter
  #                 values as input, performs a given algorithm and
  #                 returns the best fitness value found.
  # [+runs+]        The number of runs to use for each parameter
  #                 vector.
  def self.evaluate_vector(vector, parameters, algorithm, runs)

    # Transform the vector into a hash of parameter names and
    # settings and compute the mean best fitness using this
    # parameter vector across a given number of runs.
    vector = Hash[vector.to_a.each_with_index.map { |v, i|
      [parameters[i].name, v]
    }]
    Array.new(runs) { algorithm[vector] }.inject(:+).to_f / runs

  end

  # Performs REVAC mutation on an individual at a given index within the vector
  # table to produce a new mutated vector.
  #
  # ==== Parameters
  # [+random+]  The random number generator.
  # [+table+]   The vector table.
  # [+index+]   The index of the individual to mutate.
  # [+h+]       The radius of the partial marginal density function.
  #
  # ==== Returns
  # The resulting vector.
  def self.mutate(random, table, index, h)

    # Sort the values of this parameter for all vectors into ascending order
    # before calculating the upper and lower bounds of the mutation distribution
    # and drawing a new parameter value at uniform random.
    return Array.new(table[0].length) do |i|
      window = (0...table.length).sort { |x, y| table[x][i] <=> table[y][i] }
      position = window.find_index(index)
      window = [
        window[[position - h, 0].max],
        window[[position + h, table.length - 1].min]
      ]
      window = table[window[0]][i] .. table[window[1]][i]
      random.rand(window)
    end
    
  end

  # Performs a multi-parent crossover on a list of parent chromosomes to produce
  # a new chromosome.
  #
  # ==== Parameters
  # [+random+]  The random number generator.
  # [+parents+] The parents of the child chromosome.
  #
  # ==== Returns
  # The proto-child vector of the provided parent vectors.
  def self.crossover(random, parents)
    Array.new(parents[0].length) { |i| parents[random.rand(parents.length)][i] }
  end

  # Tunes a given algorithm using REVAC.
  #
  # ==== Parameters
  # [+parameters+]  A list of parameters to optimise. Each entry in the
  #                 list contains the name of the parameter and the range
  #                 of values that it can take.
  # [+opts+]        A hash of keyword options to this method.
  # [+&algorithm+]  A lambda function which takes a hash of named parameters
  #                 as its input, uses them to perform a given algorithm,
  #                 and returns the fitness of the best individual found.
  #
  # ==== Options
  # [+evaluations+] The maximum number of evaluations to perform.
  # [+parents+]     The number of parents to use when creating each child.
  # [+runs+]        The number of runs to perform for each vector.
  # [+vectors+]     The number of parameter vectors in the population.
  # [+h+]           The radius of the partial marginal density function.
  # [+output+]      The path to the output CSV file.
  #
  # ==== Returns
  # A hash containing the `optimal' parameter values for the given problem. 
  def self.tune(parameters, opts = {}, &algorithm)

    # Load the default values for any omitted parameters.
    opts[:vectors] ||= 80
    opts[:parents] ||= 40
    opts[:h] ||= 10
    opts[:runs] ||= 5
    opts[:evaluations] ||= 5000

    # The RNG to use during optimisation.
    random = Random.new

    # Convert the list of parameter name/range pairs into a list of parameter
    # objects.
    parameters = parameters.map { |n, r| Parameter.new(n, r) }

    # Initialise evolution statistics.
    oldest = 0
    iterations = 0
    evaluations = 0

    # Initialise the output CSV file.
    CSV.open(opts[:output], 'wb') do |f|
      f << ['Evaluation'] + parameters.map { |p| p.name } + ['Utility']
    end

    # Draw an initial set of parameter vectors at uniform random from
    # their initial distributions.
    table = Array.new(opts[:vectors]) do
      parameters.map { |p| random.rand(p.range) }
    end

    # Compute the utility of each parameter vector, before finding and recording
    # the best parameter vector.
    utility = table.map do |v|
      u = evaluate_vector(v, parameters, algorithm, opts[:runs])
      log(opts[:output], evaluations, v, u)
      evaluations += 1
      u
    end
    best_utility, best_vector = utility.each_with_index.min
    best_vector = table[best_vector]

    # Keep optimising until the termination condition is met.
    until evaluations == opts[:evaluations]
      
      # Select the N-best vectors from the table as the parents
      # of the next parameter vector.
      parents = (0...opts[:vectors]).sort { |x, y|
        utility[x] <=> utility[y]
      }.take(opts[:parents]).map { |i| 
        table[i]
      }

      # Perform multi-parent crossover on the N parents to create
      # a proto-child vector.
      child = crossover(random, parents)

      # Replace the oldest vector from the population with this
      # proto-child vector, before mutating it and computing its
      # utility.
      table[oldest] = child
      table[oldest] = mutate(random, table, oldest, opts[:h])
      utility[oldest] = evaluate_vector(child, parameters, algorithm, opts[:runs])

      # Update the best vector if the child vector is an improvement.
      if utility[oldest] < best_utility
        best_vector = table[oldest]
        best_utility = utility[oldest]
      end

      # Update evolution statistics and perform logging.
      iterations += 1
      evaluations += 1
      log(opts[:output], evaluations, child, utility[oldest])
      oldest = (oldest + 1) % opts[:vectors]

      # Debugging.
      puts "Generation #{iterations}: #{best_utility}"

    end

    # Return the optimal parameter vector as a hash.
    return Hash[parameters.zip(0...parameters.length).map { |param, index|
      [param.name, best_vector[index]]
    }]

  end

end
