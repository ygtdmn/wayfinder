// UI-specific types not inferred from the contract ABI

export interface Attribute {
  trait_type: string
  value: string | number
  display_type?: 'number' | 'boost_number' | 'boost_percentage' | 'date'
}