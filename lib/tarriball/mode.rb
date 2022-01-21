module Tarriball
  class Bits
    attr_accessor :read, :write, :execute

    def initialize read: false, write: false, execute: false
      @read = read
      @write = write
      @execute = execute
    end

    def to_decimal
      value = 0
      value += 1 if @execute
      value += 2 if @write
      value += 4 if @read
      value
    end

    def self.from_decimal decimal
      integer = decimal.to_i
      new(
        execute: integer & 1 > 0,
        write: integer & 2 > 0,
        read: integer & 4 > 0
      )
    end
  end

  class Mode
    attr_accessor :owner, :group, :other

    def initialize owner: Bits.new, group: Bits.new, other: Bits.new
      @owner = owner
      @group = group
      @other = other
    end

    def to_decimal
      to_octal.to_i 8
    end

    def to_octal
      [@owner.to_decimal, @group.to_decimal, @other.to_decimal].join
    end

    def self.from_decimal decimal
      integer = decimal.to_i
      octal = integer.to_s 8
      from_octal octal
    end

    def self.from_octal octal
      string = octal.to_s
      new(
        owner: Bits.from_decimal(string[-3].to_i),
        group: Bits.from_decimal(string[-2].to_i),
        other: Bits.from_decimal(string[-1].to_i)
      )
    end

    DIRECTORY_DEFAULT = new(
      owner: Bits.new(read: true, write: true, execute: true),
      group: Bits.new(read: true, execute: true),
      other: Bits.new(read: true, execute: true)
    )
    FILE_DEFAULT = new(
      owner: Bits.new(read: true, write: true),
      group: Bits.new(read: true),
      other: Bits.new(read: true)
    )
  end
end