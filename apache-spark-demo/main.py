import os
import datetime
from pyspark.sql import SparkSession

db_url = 'jdbc:postgresql://localhost:5432/database-design-and-support-lab'
db_credentials = {
    'user': 'postgres',
    'password': os.environ['DB_PASSWORD'],
    'driver': 'org.postgresql.Driver'
}


def get_spark():
    return SparkSession.builder \
        .appName('apache-spark-demo') \
        .config('spark.jars', './postgresql-42.7.4.jar') \
        .getOrCreate()


if __name__ == "__main__":
    spark = get_spark()
    df_orders = spark.read.jdbc(url=db_url, table='orders', properties=db_credentials)
    df_clients = spark.read.jdbc(url=db_url, table='clients', properties=db_credentials)
    df_rooms = spark.read.jdbc(url=db_url, table='rooms', properties=db_credentials)

    print('========= Loaded data from DB =========')
    df_orders.show()
    df_clients.show()

    print('========= Orders stats =========')
    df_orders_stats = df_orders.groupBy('room_number').agg({
        'price': 'sum',
        'room_number': 'count'
    }).withColumnsRenamed({
        'sum(price)': 'price_sum',
        'count(room_number)': 'orders_count'
    })

    df_clients_stats = df_clients.join(df_orders, [df_clients.passport == df_orders.client_passport]).groupBy('passport').agg({
        'arrival_date': 'max',
        'price': 'sum',
        'order_id': 'count'
    }).withColumnsRenamed({
        'sum(price)': 'payed_sum',
        'max(arrival_date)': 'last_arrived',
        'count(order_id)': 'orders_count'
    }).orderBy('last_arrived')

    print('========= Client stats =========')
    df_clients_stats.show()

    busy_rooms_for_now = df_orders.filter(
        (df_orders['arrival_date'] <= datetime.date.today()) & (datetime.date.today() < df_orders['departure_date'])
    ).select('room_number').distinct().withColumnRenamed('room_number', 'busy_rooms')

    print('========= Busy rooms =========')
    busy_rooms_for_now.show()

