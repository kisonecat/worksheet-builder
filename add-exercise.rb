#!/usr/bin/env ruby
require 'pathname'
require 'fileutils'

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
      opts.banner = "Usage: add-exercise.rb [options] label"

      opts.on("-rPATH", "--root=PATH", Pathname,
              "Path to search for exercises") do |p|
        args.root = p
      end

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(options)
    return args
  end
end
options = Parser.parse ARGV
$root = options.root.expand_path
$label = ARGV.pop

################################################################
# load all exercises from files under $root

exercises = {}
flavor = {}
page_numbers = {}
section_numbers = {}
exercise_numbers = {}
references = {}
exercise_order = []
paths = {}

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
        paths[label] = f
        label = nil
      end
    end
  end
end

################################################################
# filter the latex file and run pdflatex

previousFilename = paths[$label]

pn = Pathname.new(previousFilename)
previousNumber = pn.basename.to_s.gsub( /[^0-9]/, '' ).to_i

allFilenames = Dir.glob(pn.dirname.join('*.tex')).sort
previousIndex = allFilenames.index(previousFilename)
nextIndex = previousIndex + 1
thisNumber = false
if (nextIndex < allFilenames.length)
  nextNumber = Pathname.new(allFilenames[nextIndex]).basename.to_s.gsub( /[^0-9]/, '' ).to_i
  thisNumber = (previousNumber + nextNumber) / 2
else
  thisNumber = previousNumber + 100
end

thisFilename = pn.dirname.join("#{'%05d' % thisNumber}.tex")
if File.exist?( thisFilename )
  puts "ERROR: The file ${thisFilename} already exists."
  exit
else
  FileUtils.cp( $root.join( 'GUIDES' ).join( 'template.tex' ),
                thisFilename )

  editor = fork do
    puts "Opening #{thisFilename}"
    exec "open #{thisFilename}"
  end
  Process.detach(editor)
  # sleep 1
  # FileUtils.rm( thisFilename )
end
