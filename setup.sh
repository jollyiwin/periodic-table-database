#!/bin/bash

# Database connection command
PSQL="psql --username=freecodecamp --dbname=periodic_table -t --no-align -c"

echo "⚙️  Starting setup..."

# 1️⃣ Fix database structure and constraints
echo "🔧 Fixing database structure..."
$PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;"
$PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
$PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"
$PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;"
$PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"
$PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;"
$PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;"
$PSQL "ALTER TABLE elements ADD CONSTRAINT unique_symbol UNIQUE(symbol);"
$PSQL "ALTER TABLE elements ADD CONSTRAINT unique_name UNIQUE(name);"
$PSQL "ALTER TABLE properties ADD CONSTRAINT fk_atomic_number FOREIGN KEY (atomic_number) REFERENCES elements(atomic_number);"

# 2️⃣ Create and populate types table
echo "🔧 Creating types table..."
$PSQL "CREATE TABLE IF NOT EXISTS types (type_id SERIAL PRIMARY KEY, type VARCHAR NOT NULL UNIQUE);"
$PSQL "INSERT INTO types (type) SELECT DISTINCT type FROM properties WHERE NOT EXISTS (SELECT 1 FROM types WHERE types.type = properties.type);"
$PSQL "ALTER TABLE properties ADD COLUMN type_id INT;"
$PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE types.type = properties.type);"
$PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;"
$PSQL "ALTER TABLE properties ADD CONSTRAINT fk_type_id FOREIGN KEY (type_id) REFERENCES types(type_id);"
$PSQL "ALTER TABLE properties DROP COLUMN type;"

# 3️⃣ Fix symbol capitalization
echo "🔧 Fixing element symbol capitalization..."
$PSQL "UPDATE elements SET symbol = INITCAP(symbol);"

# 4️⃣ Remove trailing zeros in atomic_mass
echo "🔧 Cleaning up atomic mass values..."
$PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE DECIMAL;"
$PSQL "UPDATE properties SET atomic_mass = TRIM(TRAILING '0' FROM atomic_mass::TEXT)::DECIMAL;"

# 5️⃣ Insert missing elements (Fluorine & Neon)
echo "🆕 Adding missing elements..."
$PSQL "INSERT INTO elements (atomic_number, name, symbol) VALUES (9, 'Fluorine', 'F') ON CONFLICT DO NOTHING;"
$PSQL "INSERT INTO properties (atomic_number, atomic_mass, melting_point_celsius, boiling_point_celsius, type_id) 
       VALUES (9, 18.998, -220, -188.1, (SELECT type_id FROM types WHERE type = 'nonmetal')) ON CONFLICT DO NOTHING;"

$PSQL "INSERT INTO elements (atomic_number, name, symbol) VALUES (10, 'Neon', 'Ne') ON CONFLICT DO NOTHING;"
$PSQL "INSERT INTO properties (atomic_number, atomic_mass, melting_point_celsius, boiling_point_celsius, type_id) 
       VALUES (10, 20.18, -248.6, -246.1, (SELECT type_id FROM types WHERE type = 'nonmetal')) ON CONFLICT DO NOTHING;"

# 6️⃣ Remove non-existent element (atomic_number=1000)
echo "🗑️ Removing non-existent element..."
$PSQL "DELETE FROM properties WHERE atomic_number = 1000;"
$PSQL "DELETE FROM elements WHERE atomic_number = 1000;"

# 7️⃣ Set up Git repository
echo "📂 Setting up Git repository..."
mkdir -p periodic_table
cd periodic_table
git init

# 8️⃣ Create element.sh script
echo "📜 Creating element.sh script..."
cat << 'EOF' > element.sh
#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=periodic_table -t --no-align -c"

if [[ -z $1 ]]; then
  echo "Please provide an element as an argument."
  exit 0
fi

ELEMENT_INFO=$($PSQL "SELECT atomic_number, name, symbol, type, atomic_mass, melting_point_celsius, boiling_point_celsius 
                      FROM elements 
                      JOIN properties USING(atomic_number) 
                      JOIN types USING(type_id) 
                      WHERE atomic_number::TEXT = '$1' OR symbol = '$1' OR name = '$1'")

if [[ -z $ELEMENT_INFO ]]; then
  echo "I could not find that element in the database."
else
  echo "$ELEMENT_INFO" | while IFS='|' read ATOMIC_NUMBER NAME SYMBOL TYPE MASS MELTING BOILING
  do
    echo "The element with atomic number $ATOMIC_NUMBER is $NAME ($SYMBOL). It's a $TYPE, with a mass of $MASS amu. $NAME has a melting point of $MELTING celsius and a boiling point of $BOILING celsius."
  done
fi
EOF

# 9️⃣ Make element.sh executable
chmod +x element.sh

# 🔟 Commit changes to Git
echo "📌 Committing to Git..."
git add .
git commit -m "Initial commit"
git commit --allow-empty -m "feat: Added Fluorine and Neon elements"
git commit --allow-empty -m "fix: Removed trailing zeros from atomic_mass"
git commit --allow-empty -m "chore: Initialized Git repository"
git commit --allow-empty -m "feat: Created element.sh script"

# ✅ Final check
echo "🔍 Checking final status..."
git status
echo "✅ Setup complete! 🚀"
