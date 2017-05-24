/*
Подготовка базы данных
1. Выполнить скрипт hr_create.sql с командами создания таблиц БД.
2. Выполнить скрипт hr_popul.sql с командами заполнения таблиц БД.
*/



--	Задание 1 Создание хранимых процедур по пакетной работе с данными
/*	Повторить выполнение задания 1.2 из лабораторной работы 7, включив анонимный PL/SQL-блок в хранимую процедуру, учитывая, что:
- название процедуры – generate_emp;
- входным параметром является количество вносимых строк;
- использовать пакетную операцию внесения FORALL.
Сравнить времена выполнения PL/SQL-блоков этого задания и задания 1.2 из лабораторной работы 7.
*/
CREATE OR REPLACE PROCEDURE generate_emp 
	(num_rows IN INTEGER)
IS
  TYPE IdTab IS TABLE OF employees.employee_id%TYPE INDEX BY PLS_INTEGER;
  TYPE F_NameTab IS TABLE OF employees.first_name%TYPE INDEX BY PLS_INTEGER;
  TYPE S_NameTab IS TABLE OF employees.last_name%TYPE INDEX BY PLS_INTEGER;
  TYPE EmailTab IS TABLE OF employees.email%TYPE INDEX BY PLS_INTEGER;
  TYPE DateTab IS TABLE OF employees.hire_date%TYPE INDEX BY PLS_INTEGER;
  e_id IdTab; f_name F_NameTab; s_name S_NameTab; email EmailTab; h_date DateTab;
  iterations CONSTANT PLS_INTEGER := num_rows;
  t1 INTEGER; t2 INTEGER; delta INTEGER;
BEGIN
  t1 := DBMS_UTILITY.get_time;
  FOR j IN 1..iterations LOOP
    e_id  (j) := 300 + j;
    f_name(j) := 'Vitalii ' || TO_CHAR(j);
    s_name(j) := 'Titarenko ' || TO_CHAR(j);
    email (j) := 'VT ' || TO_CHAR(j);
    h_date(j) := to_date('01/01/2000','DD/MM/YYYY') + j;
  END LOOP;
	FORALL i IN 1..iterations
		INSERT INTO employees 
        (employee_id, first_name, last_name, email, hire_date, job_id)
		VALUES(e_id(i), f_name(i), s_name(i), email (i), h_date(i), 'FI_MGR');
  t2 := DBMS_UTILITY.get_time;
  delta := t2 - t1;
  DBMS_OUTPUT.PUT_LINE('Для FORALL-цикла: ' || TO_CHAR((delta)/100));
END;
/

--	Аналогичная процедура с операцией FOR для сравнения
CREATE OR REPLACE PROCEDURE generate_emp_FOR 
	(num_rows IN INTEGER)
IS
   t1 INTEGER; t2 INTEGER; delta INTEGER;
BEGIN
  t1 := DBMS_UTILITY.get_time;
	FOR i IN 1..num_rows LOOP
		INSERT INTO employees 
        (employee_id, first_name, last_name, email, hire_date, job_id)
		VALUES(300 + i, 
				'Vitalii ' || TO_CHAR(i), 
				'Titarenko ' || TO_CHAR(i),
				'VT ' || TO_CHAR(i),
				to_date('01/01/2000','DD/MM/YYYY') + i,
				'FI_MGR');
  END LOOP;
  t2 := DBMS_UTILITY.get_time;
  delta := t2 - t1;
  DBMS_OUTPUT.PUT_LINE('Для FOR-цикла: ' || TO_CHAR((delta)/100));
END;
/

/*	Вызов процедур:
BEGIN
	generate_emp(10000);
END;
/
ROLLBACK;
BEGIN
	generate_emp_FOR(10000);
END;
/


PL/SQL procedure successfully completed.
Для FORALL-цикла: .43
Rollback complete.
PL/SQL procedure successfully completed.
Для FOR-цикла: 7.65
*/



/*
  Этап 2 Создание хранимых процедур, функций и пакетов.
2. Создать пакет pkg_dept по управлению таблицей подразделений.
*/
CREATE OR REPLACE PACKAGE pkg_dept IS

FUNCTION drop_dept (dep_name IN VARCHAR2) RETURN NUMBER;

PROCEDURE change (dep_name_old IN VARCHAR2, dep_name_new IN VARCHAR2);

FUNCTION create_dept (dep_name IN VARCHAR2
                    , loc_name IN VARCHAR2
                    , cnt_name IN VARCHAR2
                    , reg_name IN VARCHAR2) RETURN NUMBER;

END pkg_dept;
/


CREATE OR REPLACE PACKAGE BODY pkg_dept IS

--  2.1 функция удаления заданного подразделения
FUNCTION drop_dept (dep_name IN VARCHAR2)
RETURN NUMBER
IS
	dep_id departments.department_id%TYPE;
BEGIN
	SELECT department_id INTO dep_id
		FROM departments
		WHERE department_name = dep_name;
    UPDATE employees
		SET department_id = null
		WHERE department_id = dep_id;
    UPDATE job_history
        SET department_id = null
        WHERE department_id = dep_id;
	DELETE FROM departments
        WHERE department_id = dep_id;
	RETURN dep_id;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RETURN -1;
END;

--	2.2 процедура изменения названия подразделения
PROCEDURE change (dep_name_old IN VARCHAR2, dep_name_new IN VARCHAR2)
IS
  dep_id departments.department_id%TYPE;
  dublicate exception;
BEGIN
  SELECT department_id INTO dep_id
      FROM departments
      WHERE department_name = dep_name_old;
  SELECT department_id INTO dep_id
      FROM departments
      WHERE department_name = dep_name_new;
  RAISE dublicate;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
    IF dep_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20550,
			'Department not found');
    ELSE
      UPDATE departments
        SET department_name = dep_name_new
        WHERE department_id = dep_id;
    END IF;
  WHEN dublicate THEN
    RAISE_APPLICATION_ERROR(-20560,
		'Department with name ' || dep_name_new || ' is already exists');
END;

--	2.3 функция создания подразделения, учитывая, что:
FUNCTION create_dept (dep_name IN VARCHAR2
                    , loc_name IN VARCHAR2
                    , cnt_name IN VARCHAR2
                    , reg_name IN VARCHAR2)
RETURN NUMBER
IS
	dep_id departments.department_id%TYPE;
  reg_id regions.region_id%TYPE;
	cnt_id countries.country_id%TYPE;
	loc_id locations.location_id%TYPE;
  dublicate exception;
BEGIN
  SELECT MIN(department_id) INTO dep_id
      FROM departments
      WHERE department_name = dep_name;
  IF dep_id IS NOT NULL THEN
      RAISE dublicate;
  END IF;

  SELECT region_id INTO reg_id
      FROM regions WHERE region_name = reg_name;
  SELECT country_id INTO cnt_id
      FROM countries WHERE country_name = cnt_name;
  SELECT MIN(location_id) INTO loc_id
      FROM locations WHERE city = loc_name;
  IF loc_id IS NULL THEN
      SELECT MAX(location_id)+10 INTO loc_id FROM locations;
      INSERT INTO locations VALUES(
        loc_id, NULL, NULL, loc_name, null, cnt_id);
  END IF;
  
  SELECT MAX(department_id)+10 INTO dep_id FROM departments;
    INSERT INTO departments VALUES(
        dep_id, dep_name, NULL, loc_id);
  RETURN dep_id;
EXCEPTION
	WHEN dublicate THEN
      RAISE_APPLICATION_ERROR(-20550,
			'Department already exists');
END;

END pkg_dept;
/

/*	Пример вызова:
SET SERVEROUTPUT ON
EXECUTE DBMS_OUTPUT.PUT_LINE(pkg_dept.create_dept('IT_2', 'Southlake_2', 'United States of America', 'Americas'));
*/




--	3. Создать пакет pkg_emp по управлению таблицей сотрудников
CREATE OR REPLACE PACKAGE pkg_emp IS
	TYPE emp_list IS TABLE OF VARCHAR2(500);
	FUNCTION drop_emp (dep_name IN VARCHAR2) RETURN emp_list PIPELINED;
  PROCEDURE change (emp_nam IN VARCHAR2, job_old IN VARCHAR2
                  , dep_old IN VARCHAR2, job_new IN VARCHAR2
                  , dep_new IN VARCHAR2, sal_new IN NUMBER);
END pkg_emp;
/

CREATE OR REPLACE PACKAGE BODY pkg_emp IS
--  3.1 процедура изменения информации о сотруднике
PROCEDURE change (emp_nam IN VARCHAR2, job_old IN VARCHAR2
                , dep_old IN VARCHAR2, job_new IN VARCHAR2
                , dep_new IN VARCHAR2, sal_new IN NUMBER)
IS
  emp_id employees.employee_id%TYPE;
  job_chg jobs.job_id%TYPE;
  dep_chg departments.department_id%TYPE;
  sal     employees.salary%TYPE;
  sal_shg employees.salary%TYPE;
BEGIN
SELECT employee_id INTO emp_id FROM employees e 
  JOIN jobs j ON j.job_id = e.job_id
  JOIN departments d ON d.department_id = e.department_id
    WHERE e.first_name = emp_nam
      AND j.job_title = job_old
      AND d.department_name = dep_old;

IF job_old <> job_new THEN
  SELECT job_id INTO job_chg
    FROM jobs WHERE job_title = job_new;
END IF;
IF dep_old <> dep_new THEN 
  SELECT department_id INTO dep_chg
    FROM departments WHERE department_name = dep_new;
END IF;
SELECT salary INTO sal FROM employees WHERE employee_id = emp_id;
IF sal <> sal_new THEN sal_shg := sal_new; END IF;
    
IF job_chg IS NOT NULL AND dep_chg IS NOT NULL AND sal_shg IS NOT NULL THEN
  UPDATE employees SET job_id = job_chg, salary = sal_shg,
                       department_id = dep_chg WHERE employee_id = emp_id;
END IF;

EXCEPTION	WHEN NO_DATA_FOUND THEN
  RAISE_APPLICATION_ERROR(-20550, 'Employee is not found');
END;

--  3.2 функция удаления всех сотрудников заданного подразделения
FUNCTION drop_emp (dep_name IN VARCHAR2)
  RETURN emp_list PIPELINED AS
  PRAGMA AUTONOMOUS_TRANSACTION;
	  v_emp_list emp_list := emp_list();
    dep_id departments.department_id%TYPE;
    TYPE NumList IS TABLE OF employees.employee_id%TYPE;
      enums NumList;
    TYPE NameList IS TABLE OF employees.first_name%TYPE;
      names NameList;
BEGIN
  SELECT DISTINCT e.department_id INTO dep_id
    FROM employees e
    JOIN departments d ON d.department_id = e.department_id
    WHERE d.department_name = dep_name;

  DELETE FROM employees WHERE department_id = dep_id
    RETURNING employee_id, first_name BULK COLLECT INTO enums, names;
  COMMIT;
  FOR i IN enums.FIRST .. enums.LAST LOOP
    PIPE ROW(enums(i) || ', ' || names(i));
  END LOOP;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20550, 'Nobody work in such department'); 
END;
END pkg_emp;
/

/*	Пример вызова:
SELECT * FROM TABLE(pkg_emp.drop_emp('Finance'));
*/