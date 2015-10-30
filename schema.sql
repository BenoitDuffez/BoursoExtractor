CREATE TABLE `operations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `op_date` date NOT NULL,
  `op_type` varchar(30) NOT NULL,
  `op_location` char(2) NOT NULL,
  `op_description` mediumtext,
  `op_date_valeur` date NOT NULL,
  `op_value` float(12,3) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

