-- Film film revenue table
CREATE TABLE film_revenue_table (
	film_title  TEXT NOT NULL,
	rental_cost DECIMAL (10,2) NOT NULL,
	category_name TEXT NOT NULL,
	number_of_rentals INT NOT NULL,
	total_revenue DECIMAL(10,2) NOT NULL,
	film_id INT PRIMARY KEY,
	FOREIGN KEY (film_id) REFERENCES film(film_id),
	CONSTRAINT unique_film_id UNIQUE (film_id)
);

-- Category revenue table
CREATE TABLE category_revenue_table (
	category_name TEXT NOT NULL,
	number_of_films INT NOT NULL,
	total_rentals INT NOT NULL,
	total_revenue DECIMAL(10,2) NOT NULL,
	last_rental_date DATE NOT NULL,
	category_id INT PRIMARY KEY,
	FOREIGN KEY (category_id) REFERENCES category(category_id),
	CONSTRAINT unique_category_name UNIQUE (category_name)
);

-- Employee revenue table
CREATE TABLE employee_revenue_table (
	staff_id INT NOT NULL,
	employee_name TEXT NOT NULL,
	employee_email TEXT NOT NULL,
	employee_rentals INT NOT NULL,
	employee_sales DECIMAL(10,2) NOT NULL,
	month TEXT NOT NULL,
	FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);

-- Store revenue table
CREATE TABLE store_revenue_table (
	store_id INT,
	store_rentals INT NOT NULL,
	store_revenue DECIMAL(10,2) NOT NULL,
	city TEXT NOT NULL,
	country TEXT NOT NULL,
	post_code TEXT NOT NULL,
	month TEXT NOT NULL,
	FOREIGN KEY (store_id) REFERENCES store(store_id)
);

-- Create function to update DATE to month (e.g. 'February')
CREATE OR REPLACE FUNCTION date_to_month(dateInput TIMESTAMP)
RETURNS TEXT AS $$
BEGIN
	RETURN TO_CHAR(dateInput, 'Month');
END
$$
LANGUAGE plpgsql;

-- Create Procedure to refresh data (Use job scheduler to set up routine refresh)
CREATE OR REPLACE PROCEDURE fetchData()
LANGUAGE plpgsql
AS $$
BEGIN

-- Clear tables
TRUNCATE TABLE film_revenue_table,category_revenue_table,employee_revenue_table, store_revenue_table;

INSERT INTO film_revenue_table
	SELECT 
		f.title,
		f.rental_rate,
		c.name,
		COUNT(r.rental_id),
		SUM(p.amount),
		f.film_id
	
	FROM film f
	JOIN film_category fc ON f.film_id = fc.film_id
	JOIN category c ON fc.category_id = c.category_id
	JOIN inventory i ON f.film_id = i.film_id
	JOIN rental r ON i.inventory_id = r.inventory_id
	JOIN payment p ON r.rental_id = p.rental_id
GROUP BY 
	f.title, 
	c.name, 
	f.film_id, 
	f.rental_rate;
	
INSERT INTO category_revenue_table
	SELECT 
		c.name, 
		COUNT(DISTINCT f.title),
		COUNT(r.rental_id),
		SUM(p.amount),
		MAX(r.return_date),
		c.category_id
	
	FROM category c
	JOIN film_category fc 
		ON c.category_id = fc.category_id
	JOIN film f 
		ON fc.film_id = f.film_id
	JOIN inventory i 
		ON f.film_id = i.film_id
	JOIN rental r 
		ON i.inventory_id = r.inventory_id
	JOIN payment p 
		ON r.rental_id = p.rental_id
GROUP BY 
	c.name,
	c.category_id;
	
INSERT INTO employee_revenue_table
	SELECT
		s.staff_id,
		CONCAT(s.first_name,' ',s.last_name),
		s.email,
		COUNT(r.rental_ID),
		SUM(p.amount),
		date_to_month(r.rental_date)
	FROM rental r
	JOIN payment p
		ON r.rental_id = p.rental_id
	JOIN staff s
		ON p.staff_id = s.staff_id
GROUP BY 
	s.staff_id, 
	s.first_name, 
	s.last_name, 
	s.email,
	date_to_month(r.rental_date);

INSERT INTO store_revenue_table 
	SELECT 
		store.store_id,
		COUNT(r.rental_ID),
		SUM(p.amount),
		city.city,
		country.country,
		a.postal_code,
		date_to_month(r.rental_date)
	FROM country
	JOIN city
		ON country.country_id = city.country_id
	JOIN address a
		ON city.city_id = a.city_id
	JOIN store
		ON a.address_id = store.address_id
	JOIN staff s
		ON store.store_id = s.store_id
	JOIN payment p
		ON s.staff_id = p.staff_id
	JOIN rental r
		ON p.rental_id = r.rental_id
GROUP BY store.store_id,
	city.city,
	country.country,
	a.postal_code,
	date_to_month(r.rental_date);

END;
$$

CALL fetchData();

