#!/usr/bin/env ruby

################################################################
# read command line options
require 'optparse'
require 'optparse/pathname'

Options = Struct.new(:root, :solutions, :flavor, :outputFilename)

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

      opts.on("-f", "--flavor", "Include flavor text") do
        args.flavor = true
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
$flavor = options.flavor
$outputFilename = options.outputFilename

################################################################
# load all exercises from files under $root

exercises = {}
flavor = {}
page_numbers = {}
exercise_numbers = {}


for f in Dir.glob("#{$root}/**/*.aux") do
  for line in File.open(f).readlines
    if line.match( /newlabel{([^}]*)}{{([0-9]*)}{([0-9]*)}/ )
      page_numbers[$1] = $3
      exercise_numbers[$1] = $2
    end
  end
end

for f in Dir.glob("#{$root}/**/*.tex") do
  depth = 0
  solutioning = false
  label = nil
  output = []
  
  paragraph = []
  restart = false
  
  for line in File.open(f).readlines
    if line.match( /^[ ]*$/ )
      restart = true      
    end
    
    if line.match( /\\begin *{exercise}/ )
      depth = depth + 1
      output = []
    end

    if depth == 0 and line.match( /[A-z]/ )
      if restart
        paragraph = []
        restart = false
      end
      
      paragraph << line
    end
    
    if line.match( /\\begin *{solution}/ )
      solutioning = true
    end

    if $solutions or (not solutioning)
      output << line
    end
    
    if depth > 0
      if line.match( /\\label[ ]*{([^}]*)}/ ) and label.nil?
        label = $1
      end
    end

    if line.match( /\\end *{solution}/ )
      solutioning = false
    end
    
    if line.match( /\\end *{exercise}/ )
      depth = depth - 1
      if depth == 0
        exercises[label] = output.join("")
        flavor[label] = paragraph.join("")
        label = nil
      end
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

flavors = []
for line in File.open($filename).readlines
  # line.gsub!( /%.*/, '' )
  
  if line.match(/\\exercise{([^}]+)}/)
    label = $1
    line = ""
    if $flavor and not flavors.include?( flavor[label] )
      line = line + (flavor[label].gsub(/\\ref{([^}]+)}/) { |label| exercise_numbers[Regexp.last_match[1]] }) + "\n"
      flavors << flavor[label]
    end
    line = line + "\\exerciselabel{#{exercise_numbers[label]}}{#{page_numbers[label]}}"
    line = line + exercises[label]
  end
  output.puts line
end

unless $outputFilename
  output.each do |line|
    puts line
  end
end

