path = require 'path'
program = require 'commander'

pkg = require path.resolve __dirname, '..', 'package.json'

program
.version(pkg.version)
.usage('<input.png> [output.pat]')
.option('-n, --name [Pattern Name]', 'optional pattern name')
.option('-i, --id [abcdefgh-ijkl-mnop-qrst-uvwxyz012345]', 'optional pattern id (must follow this format)')
.parse(process.argv)

if not program.args.length
  program.help()

fs = require 'fs'

sourcePath = path.resolve program.args[0]

if program.args.length is 2
  outputPath = path.resolve program.args[1]
else
  outputPath = path.basename(sourcePath, path.extname sourcePath) + '.pat'

if not fs.existsSync sourcePath
  console.error()
  console.error("  [error]: file does not exist #{sourcePath}")
  console.error()
  process.exit 1

try
  body = fs.readFileSync sourcePath
catch
  console.error()
  console.error("  [error]: file cannot be read #{sourcePath}")
  console.error()
  process.exit 1

pngparse = require 'pngparse'
patternizer = require '..'

pngparse.parse body, (err, image) =>
  if err
    console.error()
    console.error('  ', err)
    console.error()
    process.exit 1

  outputStream = fs.createWriteStream(outputPath)
  patternizer
    outputStream: outputStream
    image: image
    id: program.id or null
    name: program.name or null
    callback: ->
      outputStream.on 'close', ->
        console.log()
        console.log("  [success]: pattern created #{outputPath}")
        console.log()
