import time
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    logger.info('Scheduler service started')
    
    while True:
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        logger.info(f'Scheduler running at {current_time}')
        
        # Adicione aqui a lógica que o scheduler precisa executar
        # Por exemplo, verificação de tarefas pendentes, alertas, etc.
        
        # Espera 60 segundos antes da próxima execução
        time.sleep(60)

if __name__ == '__main__':
    main()
