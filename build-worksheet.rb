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

# BADBAD: force flavor text to appear for now
$flavor = true

################################################################
# load all exercises from files under $root

exercises = {}
flavor = {}
page_numbers = {}
section_numbers = {}
exercise_numbers = {}
references = {}

for f in Dir.glob("#{$root}/**/*.aux") do
  for line in File.open(f).readlines
    if line.match( /newlabel{([^}]*)}{{([0-9]*)}{([0-9]*)}{}{exercise.exercise.([0-9]*).([0-9]*)./ )
      section_numbers[$1] = "#{$4}.#{$5}"
      exercise_numbers[$1] = $2
    end

    
    if line.match( /newlabel{([^}]*)}{{([0-9]*)}{([0-9]*)}/ )
      page_numbers[$1] = $3
      exercise_numbers[$1] = $2
    end
    if line.match( /newlabel{([^}]*)}{({[0-9.]*}{[0-9.]*})/ )
      references[$1] = "{#{$2}}"
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

$used_references = []

def find_references(text)
  text.scan(/\\ref{([^}]*)}/) { |r|
    r = r[0]
    $used_references << r unless $used_references.include?(r)
  }
  text.scan(/\\eqref{([^}]*)}/) { |r|
    r = r[0]    
    $used_references << r unless $used_references.include?(r)
  }  
end

# Find references
for line in File.open($filename).readlines
  if line.match(/\\exercise{([^}]+)}/)
    label = $1
    find_references(flavor[label])
  end
  find_references(exercises[label])
end

flavors = []
for line in File.open($filename).readlines
  # line.gsub!( /%.*/, '' )

  if line.match(/\\begin{document}/)
    output.puts "\\makeatletter"
    for ref in $used_references
      output.puts "\\newlabel{#{ref}}#{references[ref]}"
    end
    output.puts "\\makeatother"    
  end  
  
  if line.match(/\\exercise{([^}]+)}/)
    label = $1
    line = ""
    if $flavor and not flavors.include?( flavor[label] )
      line = line + flavor[label] + "\n"
      flavors << flavor[label]
    end
    line = line + "\\exerciselabel{#{exercise_numbers[label]}}{#{section_numbers[label]}}"
    line = line + exercises[label]
  end
  
  output.puts line

end

unless $outputFilename
  output.each do |line|
    puts line
  end
end

