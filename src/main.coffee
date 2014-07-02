swapBytes = (buffer) ->
  for i in [0..buffer.length] by 2
    [buffer[i], buffer[i + 1]] = [buffer[i + 1], buffer[i]]
  buffer

randomUUID = ->
  out = ''
  for i in [0...36]
    if i in [8, 13, 18, 23]
      out += '-'
    else
      out += Math.floor(36 * Math.random()).toString(36)
  out

sizeofUnsignedInt = 4
sizeofUnsignedChar = 1
sizeofUnsignedShort = 2
dafuqPadding = 92

module.exports = (params) ->
  {name, id, image, outputStream, callback} = params
  {width, height, channels, data} = image

  name ?= 'Pattern'
  id ?= randomUUID()

  # ignore alpha (for now)
  if channels is 4
    computedChannels = 3
    alpha = true
  else if channels is 2
    computedChannels = 1
    alpha = true
  else
    computedChannels = channels
    alpha = false

  # file header
  outputStream.write new Buffer([
    0x38, 0x42, 0x50, 0x54, # intro "8BPT" string
    0x0, 0x1, # version
    0x0, 0x0, 0x0, 0x1, # patterns count (allways 1 for us)

    # pattern header
    0x0, 0x0, 0x0, 0x1, # version
    0x0, 0x0, 0x0, if computedChannels is 1 then 0x1 else 0x3 # image type RGB=3, gray=1 (not implemented indexed=2)
  ])

  # image header
  imageHeader = new Buffer(2 * sizeofUnsignedShort + sizeofUnsignedInt)
  # height
  imageHeader.writeUInt16BE(height, 0)
  # width
  imageHeader.writeUInt16BE(width, 1 * sizeofUnsignedShort)
  # pattern name length + 1 byte for its ending (0x00)
  imageHeader.writeUInt32BE name.length + 1, 2 * sizeofUnsignedShort
  # flush image header
  outputStream.write imageHeader

  # pattern name in ucs2 string
  name = new Buffer(name, 'ucs2')
  # need to swap bytes to convert from little endian to big endian
  outputStream.write swapBytes name
  # string ending
  outputStream.write new Buffer([0x0, 0x0])

  # pattern uuid length (36 in hex = 0x24)
  outputStream.write new Buffer([0x24])
  outputStream.write new Buffer(id, 'utf8')

  # 7 * 32bit integers as a header
  patternHeader = new Buffer(7 * sizeofUnsignedInt)
  # another version number
  patternHeader.writeUInt32BE 3, 0
  # size of chunk of data for pattern
  # = pattern data + header except version and pattern_size
  patternHeader.writeUInt32BE(5 * sizeofUnsignedInt + computedChannels * (width * height + 7 * sizeofUnsignedInt + sizeofUnsignedShort + sizeofUnsignedChar) + dafuqPadding, 1 * sizeofUnsignedInt)
  # top offset
  patternHeader.writeUInt32BE 0, 2 * sizeofUnsignedInt
  # left offset
  patternHeader.writeUInt32BE 0, 3 * sizeofUnsignedInt
  # bottom offset
  patternHeader.writeUInt32BE height, 4 * sizeofUnsignedInt
  # right offset
  patternHeader.writeUInt32BE width, 5 * sizeofUnsignedInt
  # bit depth
  patternHeader.writeUInt32BE 8 * computedChannels, 6 * sizeofUnsignedInt
  # flushing pattern header
  outputStream.write patternHeader

  # header for channel
  channelHeader = new Buffer(7 * sizeofUnsignedInt + sizeofUnsignedShort + sizeofUnsignedChar)
  # boolean, indicating that channel is used
  channelHeader.writeUInt32BE 1, 0
  # sample data + header except version and sample_size
  channelHeader.writeUInt32BE width * height + 23, 4
  # unused bit depth
  channelHeader.writeUInt32BE 8, 8
  # top offset
  channelHeader.writeUInt32BE 0, 12
  # left offset
  channelHeader.writeUInt32BE 0, 16
  # bottom offset
  channelHeader.writeUInt32BE height, 20
  # right offset
  channelHeader.writeUInt32BE width, 24
  # actually used bit depth
  channelHeader.writeUInt16BE 8, 28
  # compression flag
  channelHeader.writeUInt8 0, 30

  for i in [0...computedChannels]
    # headers all the same for all channels
    outputStream.write channelHeader

    # array of channel intensities (0-255)
    channelData = []
    for j in [i...data.length] by channels
      channelData.push(data[j])

    # writing data
    outputStream.write new Buffer(channelData)

  # end file padding of magic size found by mistake
  padding = new Buffer(dafuqPadding)
  padding.fill 0x0
  outputStream.write padding

  outputStream.end()

  if callback?
    callback()
