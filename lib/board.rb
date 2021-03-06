require_relative 'pieces/index'
require_relative 'error.rb'
require 'byebug'

class Board

  WHITE_POSITIONS = {
    "K" => [[0, 4]],
    "Q" => [[0, 3]],
    "B" => [[0, 2], [0, 5]],
    "N" => [[0, 1], [0, 6]],
    "R" => [[0, 0], [0, 7]],
    "P" => [[1, 0], [1, 1], [1, 2], [1, 3], [1, 4], [1, 5], [1, 6], [1, 7]]
  }

  BLACK_POSITIONS = {
    "K" => [[7, 4]],
    "Q" => [[7, 3]],
    "B" => [[7, 2], [7, 5]],
    "N" => [[7, 1], [7, 6]],
    "R" => [[7, 0], [7, 7]],
    "P" => [[6, 0], [6, 1], [6, 2], [6, 3], [6, 4], [6, 5], [6, 6], [6, 7]]
  }

  attr_accessor :grid

  def initialize(setup = true)
    @grid = Array.new(8) {Array.new(8) { EmptySquare.new } }
    set_up_pieces(:white) if setup
    set_up_pieces(:black) if setup
  end

  def [](position)
    row, col = position
    grid[row][col]
  end

  def []=(position, value)
    row, col = position
    self.grid[row][col] = value
  end

  def inspect
    grid.each do |row|
      row.each do |tile|
        print tile.class
      end
      puts
    end
    return nil
  end

  def render
    lines = []
    grid.each do |row|
      lines << row.map {|square| square.colored_symbol }
    end
    lines
  end

  def duped_board
    deep_dup = Board.new(false)
    self.grid.each_with_index do |row, row_index|
      row.each_with_index do |tile, col_index|
        deep_dup[[row_index, col_index]] = tile.dup(deep_dup)
      end
    end
    deep_dup
  end

  def move(position, new_position, color)
    if color != self[position].color
      raise NotYourPiece.new "That piece is not yours"
    elsif !valid_move?(position, new_position, color)
      raise InvalidMove.new "You can't yourself in check"
    elsif !self[position].possible_moves.include?(new_position)
      raise InvalidMove.new "You can't move there"
    else
      move_piece!(position, new_position)
    end
  end

  def valid_move?(position, new_position, color)
    dup = duped_board
    dup.move_piece!(position, new_position)
    !dup.in_check?(color)
  end

  def checkmate?(color)
    return false unless in_check?(color)
    current_color_pieces = find_pieces(color)

    current_color_pieces.each do |piece|
      piece.possible_moves.each do |possible_move|
        return false if valid_move?(piece.position, possible_move, color)
      end
    end

    true
  end

  def find_pieces(color)
    grid.flatten.select { |tile| tile.piece? && tile.color == color }
  end

  def find_king(color)
    find_pieces(color).select { |piece| piece.is_a?(King) }.first
  end

  def in_check?(color)
    my_king = find_king(color)
    opponent_pieces = find_pieces(opponent(color))

    opponent_pieces.each do |piece|
      piece.possible_moves.each do |move|
        return true if move == my_king.position
      end
    end
    false
  end

  def opponent(color)
    color == :white ? :black : :white
  end

  def in_bounds?(position)
    position.all? { |coord| coord.between?(0, grid.length-1) }
  end

  def set_up_pieces(color)
    pieces_positions = color == :white ? WHITE_POSITIONS : BLACK_POSITIONS
    pieces_positions.each do |type, positions|
      positions.each do |position|
        case type
        when "K"
          self[position] = King.new(position, color, self)
        when "Q"
          self[position] = Queen.new(position, color, self)
        when "B"
          self[position] = Bishop.new(position, color, self)
        when "N"
          self[position] = Knight.new(position, color, self)
        when "R"
          self[position] = Rook.new(position, color, self)
        when "P"
          self[position] = Pawn.new(position, color, self)
        end
      end
    end
  end

  def piece_at(position)
    self[position]
  end

  def color_at(position)
    self[position].color
  end

  def occupied?(position)
    piece_at(position).piece?
  end

  def move_piece!(position, new_position)
    current_piece = piece_at(position)
    self[new_position] = current_piece
    self[position] = EmptySquare.new
    current_piece.update_position(new_position)
    check_pawn_promotion(current_piece)
  end

  def check_pawn_promotion(current_piece)
    if current_piece.instance_of?(Pawn) && current_piece.is_promoted?
      queen = Queen.new(current_piece.position, current_piece.color, self)
      self[current_piece.position] = queen
    end
  end

  def all_moves(color)
    moves = []

    find_pieces(color).each do |piece|
      piece.possible_moves.each do |move|
        moves << [ piece.position, move ] if valid_move?(piece.position, move, color)
      end
    end
    moves.shuffle
  end

  def max_capture_value(color)
    max = 0
    all_moves(color).each do |move|
      from, to = move
      piece = self.piece_at(to)
      if !piece.empty? && self.color_at(to) != color && piece.value > max
        max = piece.value
      end
    end
    max
  end

  def scores
    results = {}
    [:white, :black].each do |color|
      # debugger
      values = self.find_pieces(color)
          .reject {|piece| piece.value.nil? }
          .map {|piece| piece.value }
      results[color] = values.inject(:+)
    end
    results
  end

end
