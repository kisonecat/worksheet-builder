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

      opts.on("-oFILE", "--output=File", "Save output to file") do |filename|
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
exercise_order = []

for f in Dir.glob("#{$root}/**/*.aux") do
  for line in File.open(f).readlines
    if line.match( /newlabel{([^}]*)}{{([0-9]*)}{([0-9]*)}{}{exercise.exercise.([0-9]*).([0-9]*)./ )
      section_numbers[$1] = "#{$4}.#{$5}"
      exercise_numbers[$1] = $2
      exercise_order << $1
    end
    
    if line.match( /newlabel{([^}]*)}{{([0-9]*)}{([0-9]*)}/ )
      page_numbers[$1] = $3
      exercise_numbers[$1] = $2
      exercise_order << $1      
    end
    if line.match( /newlabel{([^}]*)}{({[0-9.]*}{[0-9.]*})/ )
      references[$1] = "{#{$2}}"
    end
  end
end

# detect dupliates and give a warning!

for f in Dir.glob("#{$root}/**/*.tex") do
  depth = 0
  solutioning = false
  label = nil
  output = []
  
  paragraph = []
  restart = false
  preamble = true
  
  for line in File.open(f).readlines
    # this isn't safe because of \%
    # line.gsub!( /%.*/, '' )

    if line.match( /\\begin *{document}/ )
      preamble = false
      next
    end

    next unless preamble == false
    
    if line.match( /^[ ]*$/ )
      restart = true      
    end

    if line.match( /\\begin *{exercise}/ ) or line.match( /\\begin *{computerExercise}/ )
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
    
    if line.match( /\\end *{exercise}/ ) or  line.match( /\\end *{computerExercise}/ )
      depth = depth - 1
      if depth == 0
        if not exercises[label].nil?
          puts "WARNING: in #{f} the exercise #{label} appears more than once."
        end
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
    if (flavor[label].nil?)
      puts "Error: Missing label #{label}"
    end
    find_references(flavor[label])
  end
  find_references(exercises[label])
end

def remove_exercise_reference(t)
  return t if not t.match(/[a-z]/)
  t = t.split("\n\n").join("\\par ")
  t = t.split("\n").join(" ")
  t.gsub!( /In (each of )?[eE]xercises[ ~]\\ref{([^}]*)} ?-- ?\\ref{([^}]*)},? ?/, '')
  t.gsub!( /in [eE]xercises[ ~]\\ref{([^}]*)} ?-- ?\\ref{([^}]*)},? ?/, '')
  if t.match(/^\\noindent /)
    t.gsub!(/^\\noindent /, '')
    t = t[0..0].upcase + t[1..-1]
    t = "\\noindent " + t
  else
    t = t[0..0].upcase + t[1..-1]
  end
  t.gsub!( "\\par ", "\n\n" )
  return t
end

flavors = []
for line in File.open($filename).readlines
  # line.gsub!( /%.*/, '' )

  if line.match(/\\begin{document}/)
    output.puts "\\makeatletter"
    for ref in $used_references
      if references[ref]
        output.puts "\\newlabel{#{ref}}#{references[ref]}"
      end
    end
    output.puts "\\makeatother"    
  end  
  
  if line.match(/\\exercise{([^}]+)}/)
    label = $1
    if exercises[label].match(/computerExercise/)
      line = "\n\\matlabproblemlabel\n\n"
    else
      line = "\n\\problemlabel\n\n"
    end
    
    if $flavor and not flavors.include?( flavor[label] )
      text = remove_exercise_reference(flavor[label])
      line = line + text + "\n\n"
      flavors << text
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

