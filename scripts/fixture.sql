SET CHARACTER SET utf8;
SET SESSION collation_connection = 'utf8_general_ci';

CREATE TABLE IF NOT EXISTS test (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    prenom VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO test (nom, prenom)
VALUES
('Lefevre', 'Emmanuel'),
('Adulyadej', 'Bhumibol'),
('Poutine', 'Vladimir'),
('Zelensky', 'Volodymyr');
