#!/usr/bin/env ruby

################################################################
# read command line options
require 'optparse'
require 'optparse/pathname'

Options = Struct.new(:root, :solutions, :outputFilename)

class Parser
  def self.parse(options)
    args = Options.new("world")

    args.root = Pathname.new(".")
    args.solutions = false
    args.outputFilename = nil
    
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: build-worksheet.rb [options]"

      opts.on("-rPATH", "--root=PATH", Pathname,
              "Path to search for exercises") do |p|
        args.root = p
      end

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end

      opts.on("-s", "--solutions", "Include solutions") do
        args.solutions = true
      end

      opts.on("-oFILE", "--output=FILE", "Save output to file") do |filename|
        args.outputFilename = filename
      end      
    end

    opt_parser.parse!(options)
    return args
  end
end
options = Parser.parse ARGV
$root = options.root.expand_path
$filename = ARGV.pop
$solutions = options.solutions
$outputFilename = options.outputFilename

################################################################
# load all exercises from files under $root

exercises = {}

for f in Dir.glob("#{$root}/**/*.tex") do
  exercising = false
  solutioning = false
  label = nil
  output = []
  for line in File.open(f).readlines
    if line.match( /\\begin *{exercise}/ )
      exercising = true
      output = []
    end

    if line.match( /\\begin *{solution}/ )
      solutioning = true
    end

    if $solutions or (not solutioning)
      output << line
    end
    
    if exercising
      if line.match( /\\label[ ]*{([^}]*)}/ ) and label.nil?
        label = $1
      end
    end

    if line.match( /\\end *{solution}/ )
      solutioning = false
    end
    
    if line.match( /\\end *{exercise}/ )
      exercising = false
      exercises[label] = output.join("")        
      label = nil
    end
  end
end

################################################################
# filter the latex file and run pdflatex

jobname = Pathname.new($filename).basename('.tex')
output = nil
if $outputFilename
  output = File.open($outputFilename, "w")
else
  output = IO.popen("pdflatex --jobname=#{jobname}", "r+")
end

for line in File.open($filename).readlines
  line.gsub!( /%.*/, '' )
  
  if line.match(/\\exercise{([^}]+)}/)
    label = $1
    line = exercises[label]
  end
  output.puts line
end

unless $outputFilename
  output.each do |line|
    puts line
  end
end

